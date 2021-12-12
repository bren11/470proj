#remove prevous outputs
rm outFile*
for file in test_progs/*.s; do
	file=$(echo $file | cut -d'.' -f1)
	echo "Assembling $file"
	make SOURCE="$file.s" assembly > /dev/null
	echo "Running $file"
	make > /dev/null
	cd ../verisimplevOrig
	make SOURCE="$file.s" assembly > /dev/null
	make > /dev/null
	grep @@@ program.out > origOut.txt
	echo "Saving $file output"
	cd ../group9w20
	grep @@@ program.out > mineOut.txt
	echo "Checking $file output"
	#if grep @@@ program.out | grep -q WFI
	if cmp -s "../verisimplevOrig/origOut.txt" "mineOut.txt";
	then
		if cmp -s "../verisimplevOrig/writeback.out" "writeback.out";
		then
			echo -e "\e[32mPASSED\e[0m"
		else
			cp program.out outFile`ls outFile* | wc -l`.txt
			echo -e "\e[31mFAILED\e[0m"
		fi 
	else
		cp program.out outFile`ls outFile* | wc -l`.txt
		echo -e "\e[31mFAILED\e[0m"
	fi 
done
#clean directory, set for next build
make clean > /dev/null
