#!/usr/bin/env ruby
#
#
# This is metrics which outputs the Ram usage in Graphite acceptable format.
# To get the cpu stats for Windows Server to send over to Graphite.
# It basically uses the typeperf(To get available memory) and wmic(Used to get the usable memory size)
# to get the processor usage at a given particular time.
# Copyright 2013 <jashishtech@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class RamMetric < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  def getRamUsage
    tempArr1=[]
    tempArr2=[]
    IO.popen("typeperf -sc 1 \"Memory\\Available bytes\" "){
        |io| while (line=io.gets) do
                tempArr1.push(line)
            end
    }
    temp = tempArr1[2].split(",")[1]
    ramAvailableInBytes = temp[1, temp.length - 3].to_f
    timestamp = Time.now.utc.to_i
    IO.popen("wmic OS get TotalVisibleMemorySize /Value"){|io| while (line=io.gets) do tempArr2.push(line) end }
    totalRam = tempArr2[4].split('=')[1].to_f
    totalRamInBytes = totalRam*1000.0
    ramUsePercent=(totalRamInBytes - ramAvailableInBytes)*100.0/(totalRamInBytes)
    return [ramUsePercent.round(2), timestamp]
  end

  def run
    # To get the ram usage
    values = getRamUsage()
    metrics = {
        :ram => {
            :ramUsagePersec => values[0]
        }
    }
    metrics.each do|parent, children|
      children.each do|child, value|
        output [config[:scheme], parent, child].join("."), value, values[1]
      end
    end
    ok
  end
end
