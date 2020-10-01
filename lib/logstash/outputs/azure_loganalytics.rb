# encoding: utf-8

require "logstash/outputs/base"
require "logstash/namespace"
require "securerandom"

class LogStash::Outputs::AzureLogAnalytics < LogStash::Outputs::Base
  config_name "azure_loganalytics"

  # Your Operations Management Suite workspace ID
  config :customer_id, :validate => :string, :required => true

  # The primary or the secondary Connected Sources client authentication key
  config :shared_key, :validate => :string, :required => true

  # The name of the event type that is being submitted to Log Analytics. 
  # This must only contain alpha numeric and _, and not exceed 100 chars. 
  # sprintf syntax like %{my_log_type} is supported.
  config :log_type, :validate => :string, :required => true

  # The service endpoint (Default: ods.opinsights.azure.com)
  config :endpoint, :validate => :string, :default => 'ods.opinsights.azure.com'

  # The name of the time generated field.
  # Be carefule that the value of field should strictly follow the ISO 8601 format (YYYY-MM-DDThh:mm:ssZ)
  config :time_generated_field, :validate => :string, :default => ''

  # The list of key names in in-coming record that you want to submit to Log Analytics
  config :key_names, :validate => :array, :default => []

  # The list of data types for each column as which you want to store in Log Analytics (`string`, `boolean`, or `double`)
  # - The key names in `key_types` param must be included in `key_names` param. The column data whose key isn't included in  `key_names` is treated as `string` data type.
  # - Multiple key value entries are separated by `spaces` rather than commas 
  #   See also https://www.elastic.co/guide/en/logstash/current/configuration-file-structure.html#hash
  # - If you want to store a column as datetime or guid data format, set `string` for the column ( the value of the column should be `YYYY-MM-DDThh:mm:ssZ format` if it's `datetime`, and `GUID format` if it's `guid`).
  # - In case that `key_types` param are not specified, all columns that you want to submit ( you choose with `key_names` param ) are stored as `string` data type in Log Analytics.
  # Example:
  #   key_names => ['key1','key2','key3','key4',...]
  #   key_types => {'key1'=>'string' 'key2'=>'string' 'key3'=>'boolean' 'key4'=>'double' ...}
  config :key_types, :validate => :hash, :default => {}

  # Maximum number of log events to put in one request to Log Analytics
  config :max_batch_items, :validate => :number, :default => 50

  concurrency :shared

  public
  def register
    require 'azure/loganalytics/datacollectorapi/client'

    @key_types.each { |k, v|
      t = v.downcase
      if ( !t.eql?('string') && !t.eql?('double') && !t.eql?('boolean') ) 
        raise ArgumentError, "Key type(#{v}) for key(#{k}) must be either string, boolean, or double"
      end
    }

    ## Start 
    @client=Azure::Loganalytics::Datacollectorapi::Client::new(@customer_id,@shared_key,@endpoint)

  end # def register

  public
  def multi_receive(events)
    
    flush_guid = SecureRandom.uuid
    @logger.debug("Start receive: #{flush_guid}. Received #{events.length} events")

    documentsByLogType = {}  # This is a map of log_type to list of documents (themselves maps) to send to Log Analytics
    events.each do |event|
      document = {}
      
      log_type_for_event = event.sprintf(@log_type)

      event_hash = event.to_hash()
      if @key_names.length > 0
        # Get the intersection of key_names and keys of event_hash
        keys_intersection = @key_names & event_hash.keys
        keys_intersection.each do |key|
          if @key_types.include?(key)
            document[key] = convert_value(@key_types[key], event_hash[key])
          else
            document[key] = event_hash[key]
          end
        end
      else
        document = event_hash
      end
      # Skip if document doesn't contain any items
      next if (document.keys).length < 1

      if documentsByLogType[log_type_for_event] == nil then
        documentsByLogType[log_type_for_event] = []
      end
      documentsByLogType[log_type_for_event].push(document)
    end

    # Skip in case there are no candidate documents to deliver
    if documentsByLogType.length < 1
      @logger.debug("No documents in batch. Skipping")
      return
    end

    documentsByLogType.each do |log_type_for_events, events|
      events.each_slice(@max_batch_items) do |event_batch|
        begin
          @logger.debug("Posting log batch (log count: #{event_batch.length}) as log type #{log_type_for_events} to DataCollector API. First log: " + (event_batch[0].to_json).to_s)
          res = @client.post_data(log_type_for_events, event_batch, @time_generated_field)
          if Azure::Loganalytics::Datacollectorapi::Client.is_success(res)
            @logger.debug("Successfully posted logs as log type #{log_type_for_events} with result code #{res.code} to DataCollector API")
          else
            @logger.error("DataCollector API request failure (log type #{log_type_for_events}): error code: #{res.code}, data=>" + (event_batch.to_json).to_s)
          end
        rescue Exception => ex
          @logger.error("Exception occured in posting to DataCollector API as log type #{log_type_for_events}: '#{ex}', data=>" + (event_batch.to_json).to_s)
        end
      end
    end
    @logger.debug("End receive: #{flush_guid}")

  end # def multi_receive

  private
  def convert_value(type, val)
    t = type.downcase
    case t
    when "boolean"
      v = val.downcase
      return (v.to_s == 'true' ) ? true : false
    when "double"
      return Integer(val) rescue Float(val) rescue val
    else
      return val
    end
  end

end # class LogStash::Outputs::AzureLogAnalytics
