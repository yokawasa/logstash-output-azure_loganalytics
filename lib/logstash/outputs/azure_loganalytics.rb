# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "stud/buffer"

class LogStash::Outputs::AzureLogAnalytics < LogStash::Outputs::Base
  include Stud::Buffer

  config_name "azure_loganalytics"

  # Your Operations Management Suite workspace ID
  config :customer_id, :validate => :string, :required => true

  # The primary or the secondary Connected Sources client authentication key
  config :shared_key, :validate => :string, :required => true

  # The name of the event type that is being submitted to Log Analytics. This must be only alpha characters.
  config :log_type, :validate => :string, :required => true

  # The name of the time generated field. Be carefule that the value of field should strictly follow the ISO 8601 format (YYYY-MM-DDThh:mm:ssZ)
  config :time_generated_field, :validate => :string, :default => ''

  # list of Key names in in-coming record to deliver.
  config :key_names, :validate => :array, :default => []
  
  # Max number of items to buffer before flushing. Default 50.
  config :flush_items, :validate => :number, :default => 50
  
  # Max number of seconds to wait between flushes. Default 5
  config :flush_interval_time, :validate => :number, :default => 5

  public
  def register
    require 'azure/loganalytics/datacollectorapi/client'

    ## Configure
    if not @log_type.match(/^[[:alpha:]]+$/)
      raise ArgumentError, 'log_type must be only alpha characters' 
    end

    ## Start 
    @client=Azure::Loganalytics::Datacollectorapi::Client::new(@customer_id,@shared_key)

    buffer_initialize(
      :max_items => @flush_items,
      :max_interval => @flush_interval_time,
      :logger => @logger
    )

  end # def register

  public
  def receive(event)
    # Simply save an event for later delivery
    buffer_receive(event)
  end # def receive

  # called from Stud::Buffer#buffer_flush when there are events to flush
  public
  def flush (events, close=false)
  
    documents = []  #this is the array of hashes to add Azure Log Analytics
    events.each do |event|
      document = {}
      event_hash = event.to_hash()
      if @key_names.length > 0
        @key_names.each do |key|
          if event_hash.include?(key)
            document[key] = event_hash[key]
          end
        end
      else
        document = event_hash
      end
      # Skip if document doesn't contain any items
      next if (document.keys).length < 1

      documents.push(document)
    end

    # Skip in case there are no candidate documents to deliver
    if documents.length < 1
      return
    end

    begin
      res = @client.post_data(@log_type, documents, @time_generated_field)
      if not Azure::Loganalytics::Datacollectorapi::Client.is_success(res)
        @logger.error("DataCollector API request failure: error code: #{res.code}, data=>" + (documents.to_json).to_s)
      end
    rescue Exception => ex
      @logger.error("Exception occured in posting to DataCollector API: '#{ex}', data=>" + (documents.to_json).to_s)
    end

  end # def flush

end # class LogStash::Outputs::AzureLogAnalytics
