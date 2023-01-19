#!/usr/bin/env ruby 

# This script is used to play log files containing fine grained 'dyno' data into InfluxDB. This is simply timestamp 
# vs speed data recorded at a high resolution from Arduino and wheel speed sensor data.
# The Arduino output / data is captured from the serial monitor of the setup running as describerd in the below repo:
# https://github.com/david-morton/BMW_E46_Gauge_Cluster_Control

# Include required libraries
require 'influxdb-client'
require 'time'
require 'pp'

# Take the log file passed in as our input
input_file = ARGV[0]

# Create variables needed
capture_lines = false
working_hash = {}
all_results = []
run_counter = 0

# Add some blank lines to input file, bit of a hack but there ya go
File.open(input_file, 'a') do |file|
    file.write "\n\n"
  end

# Work over file and store contents of each block in array of hashes
File.readlines(input_file).each do |line|
    if line.match?(/^0,.*$/) # One time setup to record a new block of data
        working_hash = {}
        capture_lines = true
    end

    if capture_lines == true && !line.match?(/^$/)
        time_and_speed = line.chomp.split(',')
        working_hash.merge!(time_and_speed[0] => time_and_speed[1])
    end

    if capture_lines == true && line.match?(/^$/)
        all_results << working_hash
        capture_lines = false
    end
end

# Determine start time for runs as the last rounded minute
# TODO: Take user input on this so runs can be more easily compared without text file manipulation
t = Time.now().round(0)
start_time = (t - (t.to_i % 60)).strftime('%s%L').to_i

# Create client and write API for InfluxDB
influxdb_client = InfluxDB2::Client.new('http://localhost:8086', '8dGNbVBTm3', bucket: 'log-data',
  org: 'uprev', precision: InfluxDB2::WritePrecision::MILLISECOND, use_ssl: false)

influxdb_write_api = influxdb_client.create_write_api

# Splatter the CSV data into InfluxDB
all_results.each do |sample_set|
    run_counter += 1
    sample_counter = 0
    influx_name = "run_#{run_counter}"
    sample_set.each do |sample|
        time = sample[0].to_i + start_time
        speed = sample[1].to_f
        hash = { name: 'dyno_runs', fields: { influx_name => speed }, time: time }
        influxdb_write_api.write(data: hash)
        sample_counter += 1
    end
    puts "Uploaded run #{run_counter} with #{sample_counter -1} samples."
end

# Close connection to InfluxDB
influxdb_client.close!
