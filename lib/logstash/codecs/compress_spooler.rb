# encoding: utf-8
require "logstash/codecs/base"

class LogStash::Codecs::CompressSpooler < LogStash::Codecs::Base
  config_name 'compress_spooler'
  milestone 1
  config :spool_size, :validate => :number, :default => 50
  config :compress_level, :validate => :number, :default => 6

  public
  def register
    require "msgpack"
    require "zlib"
    @buffer = []
  end

  public
  def decode(data)
    z = Zlib::Inflate.new
    data = MessagePack.unpack(z.inflate(data))
    z.finish
    z.close
    data.each do |event|
      event = LogStash::Event.new(event)
      event["@timestamp"] = Time.at(event["@timestamp_f"]).utc if event["@timestamp_f"].is_a? Float
      event.remove("@timestamp_f")
      yield event
    end
  end # def decode

  public
  def encode(data)
    data["@timestamp_f"] = data["@timestamp"].to_f
    data.remove("@timestamp")
    @buffer << data.to_hash

    if @buffer.length >= @spool_size
      z = Zlib::Deflate.new(@compress_level)
      @on_event.call z.deflate(MessagePack.pack(@buffer), Zlib::FINISH)
      z.close
      @buffer.clear
    end
  end # def encode

  public
  def teardown
    if !@buffer.nil? and @buffer.length > 0
      @on_event.call @buffer
    end
    @buffer.clear
  end
end # class LogStash::Codecs::CompressSpooler
