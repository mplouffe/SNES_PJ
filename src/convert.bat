@echo off

set name="chewie"

set path=%path% ;..\bin\

superfamiconv -B 4 -i %name%.png -p %name%.pal -t %name%.chr -m %name%.map

pause