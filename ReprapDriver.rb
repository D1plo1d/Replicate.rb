require 'rubygems'
require 'serialport'
#gem install serialport

class ReprapDriver
  
  def self.all
    #POSIX
    return Dir.glob(["/dev/ttyUSB*"])
    #Windows
    #TODO: if windows return other shiz
  end

  def initialize(portName, checksums)
    @checksums = checksums
    @line_counter = -1
    @port = SerialPort.new portName, 19200, 8, 1, SerialPort::NONE
    @port.read_timeout=0 #does not return from read until a byte is received
    reset
  end

  def reset
    # Briefly pulse the RTS line low.  On most arduino-based boards, this will hard reset the
    # device.
    @port.dtr = 0
    @port.rts = 0
    sleep(0.2);
    @port.dtr = 1
    @port.rts = 1
    sleep(0.3); #give the arduino some startup time
    print("M110") #reset the current line number
  end

  def print(gcode)
    gcode.each_line { |line| print_gcode_line(line) }
  end
  
  def print_file(filename)
    File.open(filename, "r") do |infile|
      while (line = infile.gets)
        print_gcode_line(line)
      end
    end
  end

  def print_gcode_line(line)
    line = line.strip
    #skip comment and null lines
    if !(line.length == 0 || line[0] == ';' || line[0] == '(' || line[0] == '\n' || line[0] == '\r') then
      if line.scan(/[Mm]110/)[0]!=nil then #M110 = reset current line number
        @line_counter = -1
      end
      print_gcode_line!(@line_counter+=1, line)
    end
  end

  def print_gcode_line!(line_number, line)
    # send the line of gcode + any checksum/line numbering and then check/resend bad checksum lines
    # RepRap Syntax: N<linenumber> <cmd> *<chksum>\n
    # Makerbot Syntax: <cmd>\n
    # Comments: ;<comment> OR (<comment>)
    gcode = line.gsub(/;.*|\(.*?\)/,'').strip
    while true
      #remove comments and whitespace from command lines and adding line numbers
      line = ("N"+line_number.to_s+' '+gcode).strip+' '
      checksum = 0
      line.each_byte { |b| checksum ^= b } #calculate the checksum byte
      line = line +'*'+checksum.to_s+"\n" #add checksum
      puts line
      @port.write line #send the gcode
      response = ""
      resend_line = {}
      while resend_line.length == 0
        response += @port.getc.chr
        if response.include?("ok") then
          if (debug = response.scan(/DEBUG:.*/)[0])!=nil then
            puts debug #echoing debug infor from serial port
          end
          return true # success ^_^
        end
        resend_line = response.scan(/Resend:([0-9]*)[^0-9]/)
      end
      #== Bad Checksum ==
      #preparing to resend the requested bad checksum line
      #(since we wait for the 'ok' response it must be the line we just sent so any other # = fubar)
      $stderr.puts response.to_s + "\n<RESPONSE> Re-sending gcode: "+gcode.to_s
      if line_number != resend_line[0][0] then
        $stderr.puts "<RESPONSE> line number is fubared, resetting"
        print("M110") #reset line number
        line_number = (@line_counter+=1) #reset the line number for this gcode we've got to resend
      end
    end
  end
end

