######################
# P3 Autograder Check
######################

# Color Scheme
red=`tput setaf 1`
green=`tput setaf 2`
blue=`tput setaf 4`
yellow=`tput setaf 3`
purple=`tput setaf 5`
reset=`tput sgr0`

# Use original "single cycle" pipeline as
# ground truth.
TRUTH=standard/verisimplev/
TRUTH_OUT=golden_standard.txt

# Use pipeline with forwarding and harzard
# detection to check against
WORKING=./
WORKING_OUT=working_out.txt

# Diff checking
DIFF_OUT=diff_check.txt
ASSBLY_OUT=compile_out.txt

# Test Cases
LIST={}

# Generate outputs
> ${TRUTH_OUT}
> ${WORKING_OUT}
> ${DIFF_OUT}

#Statistics
stats_fn=p4_results.csv
> ${stats_fn}
echo "TestName, N, ROB, RS, CPI" > ${stats_fn}
# Test all ASSEMBLY test cases
for file in ${WORKING}test_progs/insertionsort.c; do #TODO: Change back to *

	# Get relative path
	file=${file#${WORKING}}
	filename=$(basename -- "$file");
	extension="${filename##*.}"
	test_name="${filename%.*}"

	echo -e "\n${yellow}######################################################${reset}"
	echo -e   "${yellow}# RUNNING TEST CASE:${file}${reset}"
	echo -e   "${yellow}######################################################${reset}"

	###############################
	#       Create Standard       #
	###############################
	STD_OUT_FN="std_out_${test_name}.out";
	STD_OUT_PIPE_PATH="std_out/pip/${STD_OUT_FN}"
	STD_OUT_WB_PATH="std_out/wb/${STD_OUT_FN}"
	STD_OUT_MEM_Path="std_out/mem/${STD_OUT_FN}"

	# Only Run if necessary
	#if [ ! -f "$STD_OUT_MEM_Path" ] && [ ! -f "$STD_OUT_WB_PATH" ]; then
		# Make test case program
		if [ "$extension" == "s" ]
		then
			echo -n   "${reset}Assembling Standard...${reset}"	
			output=`( cd ${TRUTH} && make assembly SOURCE=$file ) 2>&1` || echo $output
		elif [ "$extension" == "c" ]
		then
			echo -n   "${reset}Compiling Standard...${reset}"	
			output=`( cd ${TRUTH} && make program SOURCE=$file ) 2>&1` || echo $output
		fi

		# Run test Case
		if [[ "$extension" == "s" || "$extension" == "c" ]]
		then
			echo -e   "${reset}\nRunning Standard...${reset}\n"
			( cd ${TRUTH} && make ) | grep @@@ > ${STD_OUT_MEM_Path} 
			( cd ${TRUTH} &&  echo "$(cat writeback.out)") > ${STD_OUT_WB_PATH}
		fi
	#fi
	

    
	#
	# Parameter Sweep
	#
	for N in $(seq 3 3)
	do
		for ROB in $(seq 32 32)
		do
			for RS in $(seq 16 16)
			do
				cp sys_defs_stat_copy.txt sys_defs.svh
				sed -i "s/@N@/$N/g" sys_defs.svh
				sed -i "s/@ROB@/$ROB/g" sys_defs.svh
				sed -i "s/@RS@/$RS/g" sys_defs.svh

				################################
				#     Compile For Working      #
				################################
				WRK_OUT_FN="wrk_out_${test_name}.out";
				WRK_OUT_PIPE_PATH="wrk_out/pip/${WRK_OUT_FN}"
				WRK_OUT_MEM_Path="wrk_out/mem/${WRK_OUT_FN}"
				WRK_OUT_WB_Path="wrk_out/wb/${WRK_OUT_FN}"

				# Make test case program again
				if [ "$extension" == "s" ]	
				then
					echo -e   "${reset}Assembling Working...${reset}"	
					output=`( cd ${WORKING} && make assembly SOURCE=$file) 2>&1` || echo $output
				elif [ "$extension" == "c" ]
				then
					echo -e   "${reset}Compiling Working...${reset}"	
					output=`( cd ${WORKING} && make program SOURCE=$file) 2>&1` || echo $output
				fi

				
				######################
				#   Run test Case    #
				######################
				if [[ "$extension" == "s" || "$extension" == "c" ]] 
				then
					make simv &> /dev/null
					echo -e   "${reset}Running Working...${reset}"
					CPI=$( cd ${WORKING} && ./simv | tee  >(grep @@@ > ${WRK_OUT_MEM_Path}) | grep "CPI" | cut -d' ' -f9 )
					( cd ${WORKING} &&  echo "$(cat writeback.out)") > ${WRK_OUT_WB_Path}

					#
					# Write Results
					#
					echo "$test_name, $N, $ROB, $RS, $CPI" >> ${stats_fn}
					echo "Test Name:$test_name | N:$N | ROB:$ROB | RS: $RS | CPI: $CPI"

					#
					# Check Result
					#
					status=1

					echo -n "${reset}Checking Writeback Ouput...${reset}"
					result=$(diff -y "${STD_OUT_WB_PATH}" "${WRK_OUT_WB_Path}")
					if [ $? -eq 0 ]
					then
							echo "${green} PASSED${reset}"
					else
							echo "${red} FAILED${reset}"
							echo "${red}$result${reset}"
							status=0
					fi

					echo -n "${reset}Checking Memory Ouput...${reset}"
					result=$(diff -y "${STD_OUT_MEM_Path}" "${WRK_OUT_MEM_Path}")
					if [ $? -eq 0 ]
					then
							echo "${green} PASSED${reset}"
					else
							echo "${red} FAILED${reset}"
							echo "${red}$result${reset}"
							status=0
					fi

					#if [[ $status -eq 0 ]]
					#then
					#	break
					#fi
				fi

				echo -e

			done
		done
	done

	echo -e

done
