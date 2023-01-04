#!/usr/bin/env ruby 

# Future improvements ?
#   - Seperate app for 'real time' dash where we can play back and view metrics at point in time

# Include required libraries
require 'csv'
require 'influxdb-client'

# Take the CSV file passed in as our input
input_file = ARGV[0]

# Create array to store data headers and populate from file
header_values = CSV.read(input_file, headers: true).headers

# Create array of arrays representing our data values, drop the header line
data_values = CSV.read(input_file)
data_values.shift

# Create client and write API for InfluxDB
influxdb_client = InfluxDB2::Client.new('http://localhost:8086', '8dGNbVBTm3', bucket: 'log-data',
  org: 'uprev', precision: InfluxDB2::WritePrecision::MILLISECOND, use_ssl: false)

influxdb_write_api = influxdb_client.create_write_api

# Work out the total duration of log data
log_duration_ms = data_values[data_values.count.to_i - 1][0].to_i - data_values[0][0].to_i

# Mark start time in milliseconds
start_time = Time.now.strftime('%s%L').to_i - log_duration_ms

# Splatter the CSV data into InfluxDB
data_values.each_with_index do |row,index|
    timestamp = start_time + row[0].to_i
    values_hash = Hash[header_values.zip row]
    values_hash.each {|k,v| values_hash[k] = v.to_f}
    hash = { name: 'logger_metrics', fields: values_hash, time: timestamp }
    influxdb_write_api.write(data: hash)
end

# Close connection to InfluxDB
influxdb_client.close!
