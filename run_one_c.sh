echo "Enter name of c file (example: omegalul.c)"
read source
make simv > /dev/null
make program SOURCE=test_progs/$source
./simv > program.out
grep @@@ program.out > mineOut.txt
cd ../verisimplevOrig
make simv > /dev/null
make program SOURCE=test_progs/$source
./simv > program.out
grep @@@ program.out > ../group9w20/origOut.txt
cat writeback.out > ../group9w20/writeback.correct.out
cd ../group9w20
if cmp -s "origOut.txt" "mineOut.txt";
	then
		if cmp -s "writeback.correct.out" "writeback.out";
		then
			echo -e "\e[32mPASSED\e[0m"
		else
			echo -e "\e[31mFAILED\e[0m"
		fi 
	else
		echo -e "\e[31mFAILED\e[0m"
	fi 
