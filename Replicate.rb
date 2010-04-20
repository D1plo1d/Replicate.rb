require 'ReprapDriver'

def prepare(driver)
driver.print("
G90;Absolute
M104 0;Reset temperature
G28;Home
G1 F3000
G1 X50 Y5 F3000
")
end

skeinforge_dir = "/usr/local/skeinforge18/skeinforge/"
port = ReprapDriver.all[0]
if (port == nil)
  puts "Error: No RepRap detected. Please try plugging it in."
  exit
end
puts port
driver = ReprapDriver.new(port, true)

lastArg = nil
ARGV.each do |arg|
  if lastArg!=nil then
    if lastArg=="-file" then
      gcode_file = arg[0..arg.length-5]+"_export.gcode"
      if arg[arg.length-4..arg.length-1] == ".stl" then
        # Reset the Printer
        prepare(driver)
        # Skeinforge the STL
        puts "skeinforging.. Please wait an EXTREMELY long time"
        bb = IO.popen("cd "+skeinforge_dir+";./skeinforge.py "+arg)
        b = bb.readlines
        puts b.join
        # Print the GCode
        driver.print_file(gcode_file)
        prepare(driver)
      elsif arg[arg.length-6..arg.length-1] == ".gcode" then
        driver.print_file(arg)
        prepare(driver)
      end
    end
    lastArg = nil
  elsif arg=="-reset" then
    prepare(driver)
  else
    lastArg = arg
  end
end
