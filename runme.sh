# 

perl bin/qm2dot.pl qm.log
cat qm.hex | xxd -r -p > qm.dat
perl -S dat2png.pl -r 1 qm.dat qm.png
ots stamp qm.png
sh bin/gviz.sh qm.dot

