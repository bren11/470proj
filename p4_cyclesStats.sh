######################
# P3 Autograder Check
######################

TEST_NAME=$1
date

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
stats_fn="${TEST_NAME}_results.csv"
> ${stats_fn}
echo "N, ROB size, RS size, Cache Size, Unrolls, Optimization Lvl, Cycles, Instructions, Icache hit, Dcache hit, ROB hzrds, RS hzrds, LSQ hzrds" > ${stats_fn}

###############################
#       Create Standard       #
###############################
STD_OUT_MEM_Path="std_out.out"

cd ${WORKING}

echo -n   "${reset}Assembling Standard...${reset}"

output=`( make assembly SOURCE=test_progs/${TEST_NAME}/${TEST_NAME}-1-1.s ) 2>&1` || echo $output
( make ) | grep @@@ > ${STD_OUT_MEM_Path} 

for N in $(seq 1 4)
do
    for ROB in 16 32
    do
        for RS in 8 16
        do
            for CACHE in 16 64
            do

                echo -e "\n${yellow}######################################################${reset}"
                echo -e   "${yellow}# RUNNING AT N:${N}, ROB:${ROB}, RS:${RS}, CACHE:${CACHE}"
                echo -e   "${yellow}######################################################${reset}"

                make simv N_NUM=${N} ROB_NUM=${ROB} RS_NUM=${RS} CACHE_NUM=${CACHE} &> /dev/null

                for unrolls in $(seq 1 4) 
                do
                    cycles="0"
                    instr="0"
                    icache="0.0"
                    dcache="0.0"
                    robHzrd="0"
                    rsHzrd="0"
                    lsqHzrd="0"
                    for opt in $(seq 1 8) 
                    do
                        if test -f "test_progs/${TEST_NAME}/${TEST_NAME}-${unrolls}-${opt}.s"; then
                            # Get relative path
                            file="test_progs/${TEST_NAME}/${TEST_NAME}-${unrolls}-${opt}.s"

                            echo -e "\n${yellow}######################################################${reset}"
                            echo -e   "${yellow}# RUNNING TEST CASE:${file}${reset}"
                            echo -e   "${yellow}######################################################${reset}"

                            ################################
                            #     Compile For Working      #
                            ################################
                            WRK_OUT_MEM_Path="wrk_out.out"

                            # Make test case program again
                            echo -e   "${reset}Assembling Working...${reset}"	
                            output=`( make assembly SOURCE=$file) 2>&1` || echo $output

                            echo -e   "${reset}Running Working...${reset}"
                            text=$( ./simv | tee  >(grep @@@ > ${WRK_OUT_MEM_Path}) | grep "CPI" )
                            cycles=$(echo "$text" | cut -d' ' -f3)
                            instr=$(echo "$text" | cut -d' ' -f6)
                            icache=$(echo "$text" | cut -d' ' -f11)
                            dcache=$(echo "$text" | cut -d' ' -f12)
                            robHzrd=$(echo "$text" | cut -d' ' -f13)
                            rsHzrd=$(echo "$text" | cut -d' ' -f14)
                            lsqHzrd=$(echo "$text" | cut -d' ' -f15)

                            echo -n "${reset}Checking Memory Ouput...${reset}"
                            echo $(diff -y "${STD_OUT_MEM_Path}" "${WRK_OUT_MEM_Path}")

                            echo -e
                        fi
                        echo "$N, ${ROB}, ${RS}, ${CACHE}, $unrolls, $opt, $cycles, $instr, $icache, $dcache, $robHzrd, $rsHzrd, $lsqHzrd" >> ${stats_fn}
                    done
                done
            done
        done
    done
done
date