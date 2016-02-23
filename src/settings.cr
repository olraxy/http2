require "./config"
require "./errors"

module HTTP2
  class Settings
    # See https://tools.ietf.org/html/rfc7540#section-11.3
    enum Identifier : UInt16
      HEADER_TABLE_SIZE = 0x1
      ENABLE_PUSH = 0x2
      MAX_CONCURRENT_STREAMS = 0x3
      INITIAL_WINDOW_SIZE = 0x4
      MAX_FRAME_SIZE = 0x5
      MAX_HEADER_LIST_SIZE = 0x6
    end

    setter header_table_size
    property max_concurrent_streams
    setter initial_window_size
    property max_header_list_size

    @header_table_size : Int32?
    @enable_push : Bool?
    @max_concurrent_streams : Int32?
    @initial_window_size : Int32?
    @max_frame_size : Int32?
    @max_header_list_size : Int32?

    def initialize(@header_table_size = nil,
                   @enable_push = nil,
                   @max_concurrent_streams = nil,
                   @initial_window_size = nil,
                   @max_frame_size = nil,
                   @max_header_list_size = nil)
    end

    def header_table_size
      @header_table_size || DEFAULT_HEADER_TABLE_SIZE
    end

    def enable_push
      @enable_push || DEFAULT_ENABLE_PUSH
    end

    def enable_push=(value : Int)
      @enable_push = value == 1
    end

    def enable_push=(value : Bool)
      @enable_push = value
    end

    def initial_window_size
      @initial_window_size || DEFAULT_INITIAL_WINDOW_SIZE
    end

    def initial_window_size=(size)
      raise Error.flow_control_error unless MINIMUM_WINDOW_SIZE < size < MAXIMUM_WINDOW_SIZE
      @initial_window_size = size
    end

    def max_frame_size
      @max_frame_size || DEFAULT_MAX_FRAME_SIZE
    end

    def max_frame_size=(size)
      raise Error.protocol_error unless MINIMUM_FRAME_SIZE < size < MAXIMUM_FRAME_SIZE
      @max_frame_size = size
    end

    def self.parse(bytes)
      new.tap(&.parse(bytes))
    end

    def parse(bytes : Slice(UInt8))
      parse(MemoryIO.new(bytes), bytes.size / 6)
    end

    def parse(io, size)
      size.times do |i|
        id = io.read_bytes(UInt16, IO::ByteFormat::BigEndian)
        value = io.read_bytes(UInt32, IO::ByteFormat::BigEndian).to_i32

        case Identifier.from_value(id)
        when Identifier::HEADER_TABLE_SIZE
          self.header_table_size = value
        when Identifier::ENABLE_PUSH
          self.enable_push = value
        when Identifier::MAX_CONCURRENT_STREAMS
          self.max_concurrent_streams = value
        when Identifier::INITIAL_WINDOW_SIZE
          self.initial_window_size = value
        when Identifier::MAX_FRAME_SIZE
          self.max_frame_size = value
        when Identifier::MAX_HEADER_LIST_SIZE
          self.max_header_list_size = value
        end
      end

      nil
    end

    def to_payload
      payload = Slice(UInt8).new(size * 6)
      io = MemoryIO.new(payload)

      {% for name in Identifier.constants %}
        if value = @{{ name.underscore }}
          io.write_bytes(Identifier::{{ name }}.to_u16, IO::ByteFormat::BigEndian)
          if value.is_a?(Bool)
            io.write_bytes(value ? 1_u32 : 0_u32, IO::ByteFormat::BigEndian)
          else
            io.write_bytes(value.to_u32, IO::ByteFormat::BigEndian)
          end
        end
      {% end %}

      payload
    end

    # :nodoc:
    macro def size : Int32
      num = 0
      {% for name in Identifier.constants %}
        num += 1 if @{{ name.underscore }}
      {% end %}
      num
    end
  end
end