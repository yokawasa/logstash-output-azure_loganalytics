# Azure Log Analytics output plugin for Logstash 
logstash-output-azure_loganalytics is a logstash plugin to output to Azure Log Analytics. [Logstash](https://www.elastic.co/products/logstash) is an open source, server-side data processing pipeline that ingests data from a multitude of sources simultaneously, transforms it, and then sends it to your favorite [destinations](https://www.elastic.co/products/logstash). [Log Analytics](https://azure.microsoft.com/en-us/services/log-analytics/) is a service in Operations Management Suite (OMS) that helps you collect and analyze data generated by resources in your cloud and on-premises environments. It gives you real-time insights using integrated search and custom dashboards to readily analyze millions of records across all of your workloads and servers regardless of their physical location. The plugin stores in-coming events to Azure Log Analytics by leveraging [Log Analytics HTTP Data Collector API](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-collector-api)

## Installation

You can install this plugin using the Logstash "plugin" or "logstash-plugin" (for newer versions of Logstash) command:
```
bin/plugin install logstash-output-azure_loganalytics
# or
bin/logstash-plugin install logstash-output-azure_loganalytics  (Newer versions of Logstash)
```
Please see [Logstash reference](https://www.elastic.co/guide/en/logstash/current/offline-plugins.html) for more information.

## Configuration

```
output {
    azure_loganalytics {
        customer_id => "<OMS WORKSPACE ID>"
        shared_key => "<CLIENT AUTH KEY>"
        log_type => "<LOG TYPE NAME>"
        key_names  => ['key1','key2','key3'..] ## list of Key names
        key_types => {'key1'=> 'string' 'key2'=>'double' 'key3'=>'boolean' .. }
        flush_items => <FLUSH_ITEMS_NUM>
        flush_interval_time => <FLUSH INTERVAL TIME(sec)>
    }
}
```

 * **customer\_id (required)** - Your Operations Management Suite workspace ID
 * **shared\_key (required)** - The primary or the secondary Connected Sources client authentication key.
 * **log\_type (required)** - The name of the event type that is being submitted to Log Analytics. It must only contain alpha numeric and _, and not exceed 100 chars. sprintf syntax like `%{my_log_type}` is supported.
 * **time\_generated\_field (optional)** - Default:''(empty string) The name of the time generated field. Be carefule that the value of field should strictly follow the ISO 8601 format (YYYY-MM-DDThh:mm:ssZ). See also [this](https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-collector-api#create-a-request) for more details
 * **key\_names (optional)** - Default:[] (empty array). The list of key names in in-coming record that you want to submit to Log Analytics.
 * **key\_types (optional)** - Default:{} (empty hash). The list of data types for each column as which you want to store in Log Analytics (`string`, `boolean`, or `double`)
   * The key names in `key_types` param must be included in `key_names` param. The column data whose key isn't included in  `key_names` is treated as `string` data type.
   * Multiple key value entries are separated by `spaces` rather than commas (See also [this](https://www.elastic.co/guide/en/logstash/current/configuration-file-structure.html#hash))
   * If you want to store a column as datetime or guid data format, set `string` for the column ( the value of the column should be `YYYY-MM-DDThh:mm:ssZ format` if it's `datetime`, and `GUID format` if it's `guid`).
   * In case that `key_types` param are not specified, all columns that you want to submit ( you choose with `key_names` param ) are stored as `string` data type in Log Analytics.
 * **flush_items (optional)** - Default 50. Max number of items to buffer before flushing (1 - 1000).
 * **flush_interval_time (optional)** - Default 5. Max number of seconds to wait between flushes.

> [NOTE] There is a special param for changing the Log Analytics API endpoint (mainly for supporting Azure sovereign cloud)
> * **endpoint (optional)** - Default: ods.opinsights.azure.com 

## Tests

Here is an example configuration where Logstash's event source and destination are configured as Apache2 access log and Azure Log Analytics respectively.

### Example Configuration
```
input {
    file {
        path => "/var/log/apache2/access.log"
        start_position => "beginning"
    }
}

filter {
    if [path] =~ "access" {
        mutate { replace => { "type" => "apache_access" } }
        grok {
            match => { "message" => "%{COMBINEDAPACHELOG}" }
        }
    }
    date {
        match => [ "timestamp" , "dd/MMM/yyyy:HH:mm:ss Z" ]
    }
}

output {
    azure_loganalytics {
        customer_id => "818f7bbc-8034-4cc3-b97d-f068dd4cd659"
        shared_key => "ppC5500KzCcDsOKwM1yWUvZydCuC3m+ds/2xci0byeQr1G3E0Jkygn1N0Rxx/yVBUrDE2ok3vf4ksXxcBmQQHw==(dummy)"
        log_type => "ApacheAccessLog"
        key_names  => ['logid','date','processing_time','remote','user','method','status','agent']
        flush_items => 10
        flush_interval_time => 5
    }
    # for debug
    stdout { codec => rubydebug }
}
```

You can find example configuration files in logstash-output-azure_loganalytics/examples.

### Run the plugin with the example configuration

Now you run logstash with the the example configuration like this:
```
# Test your logstash configuration before actually running the logstash
bin/logstash -f logstash-apache2-to-loganalytics.conf --configtest
# run
bin/logstash -f logstash-apache2-to-loganalytics.conf
```

Here is an expected output for sample input (Apache2 access log):

<u>Apache2 access log</u>
```
106.143.121.169 - - [29/Dec/2016:01:38:16 +0000] "GET /test.html HTTP/1.1" 304 179 "-" "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36"
```

<u>Output (rubydebug)</u>
```
{
        "message" => "106.143.121.169 - - [29/Dec/2016:01:38:16 +0000] \"GET /test.html HTTP/1.1\" 304 179 \"-\" \"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36\"",
       "@version" => "1",
     "@timestamp" => "2016-12-29T01:38:16.000Z",
           "path" => "/var/log/apache2/access.log",
           "host" => "yoichitest01",
           "type" => "apache_access",
       "clientip" => "106.143.121.169",
          "ident" => "-",
           "auth" => "-",
      "timestamp" => "29/Dec/2016:01:38:16 +0000",
           "verb" => "GET",
        "request" => "/test.html",
    "httpversion" => "1.1",
       "response" => "304",
          "bytes" => "179",
       "referrer" => "\"-\"",
          "agent" => "\"Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36\""
}
```

## Debugging
If you need to debug and watch what this plugin is sending to Log Analytics, you can change the logstash log level for this plugin to `DEBUG` to get additional logs in the logstash logs.

One way of changing the log level is to use the logstash API:

```
> curl -XPUT 'localhost:9600/_node/logging?pretty' -H "Content-Type: application/json" -d '{ "logger.logstash.outputs.azureloganalytcs" : "DEBUG" }'
{
  "host" : "yoichitest01",
  "version" : "6.5.4",
  "http_address" : "127.0.0.1:9600",
  "id" : "d8038a9e-02c6-411a-9f6b-597f910edc54",
  "name" : "yoichitest01",
  "acknowledged" : true
}
```

You should then be able to see logs like this in your logstash logs:

```
[2019-03-29T01:18:52,652][DEBUG][logstash.outputs.azureloganalytics] Posting log batch (log count: 50) as log type HealthCheckLogs to DataCollector API. First log: {"message":{"Application":"HealthCheck.API","Environments":{},"Name":"SystemMetrics","LogLevel":"Information","Properties":{"CPU":3,"Memory":83}},"beat":{"version":"6.5.4","hostname":"yoichitest01","name":"yoichitest01"},"timestamp":"2019-03-29T01:18:51.901Z"}

[2019-03-29T01:18:52,819][DEBUG][logstash.outputs.azureloganalytics] Successfully posted logs as log type HealthCheckLogs with result code 200 to DataCollector API
```

Once you're done, you can use the logstash API to undo your log level changes:

```
> curl -XPUT 'localhost:9600/_node/logging/reset?pretty'
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yokawasa/logstash-output-azure_loganalytics.
