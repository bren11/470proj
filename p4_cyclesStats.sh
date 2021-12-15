######################
# P3 Autograder Check
######################

#TEST_NAME=$1
date
WORKING=./

# Color Scheme
red=`tput setaf 1`
green=`tput setaf 2`
blue=`tput setaf 4`
yellow=`tput setaf 3`
purple=`tput setaf 5`
reset=`tput sgr0`


for TEST_NAME in min_distance fc_forward rv32_copy cv32_evens rv32_fib rv32_max rv32_mult rv32_parallel 
    do
    stats_fn="${TEST_NAME}_results.csv"
    > ${stats_fn}
    echo "N, ROB size, RS size, Cache Size, Memory Latency, Branch Type, Unrolls, Cycles, Instructions, Branch hit, Icache hit, Dcache hit, ROB hzrds, RS hzrds, LSQ hzrds" > ${stats_fn}

    ###############################
    #       Create Standard       #
    ###############################
    STD_OUT_MEM_Path="std_out.out"

    cd ${WORKING}

    echo -n   "${reset}Assembling Standard...${reset}"

    output=`( make assembly SOURCE=test_progs/${TEST_NAME}/${TEST_NAME}-1-1.s ) 2>&1` || echo $output
    ( make ) | grep @@@ > ${STD_OUT_MEM_Path} 

    rm -r progs
    mkdir progs

    for unrolls in $(seq 1 4) 
    do
        for opt in 8 7 6 5 4 3 2 1
        do
            if test -f "test_progs/${TEST_NAME}/${TEST_NAME}-${unrolls}-${opt}.s"; then
                output=`( make assembly SOURCE=test_progs/${TEST_NAME}/${TEST_NAME}-${unrolls}-${opt}.s) 2>&1` || echo $output
                cp program.mem progs/${TEST_NAME}-${unrolls}.s
                break
            fi
        done
    done

    for N in 1 2 3 4
    do
        for ROB in 12 24 32
        do
            for CACHE in 8 16 64
            do
                for LATENCY in 100 1000
                do
                    for BRANCH in 1 2 3
                    do
                        echo -e "\n${yellow}######################################################${reset}"
                        echo -e   "${yellow}# RUNNING AT N:${N}, ROB:$ROB, CACHE:${CACHE}, LATENCY:$LATENCY, BRANCH:$BRANCH"
                        echo -e   "${yellow}######################################################${reset}"
                        RS=$(($ROB/2))
                        rm simv
                        make simv N_NUM=${N} ROB_NUM=${ROB} RS_NUM=${RS} CACHE_NUM=${CACHE} MEM_NUM=${LATENCY} BRANCH_NUM=${BRANCH} &> /dev/null

                        for unrolls in $(seq 1 4) 
                        do
                            # Get relative path
                            file="progs/${TEST_NAME}-${unrolls}.s"

                            echo -e "\n${yellow}######################################################${reset}"
                            echo -e   "${yellow}# RUNNING TEST CASE:${file}${reset}"
                            echo -e   "${yellow}######################################################${reset}"

                            ################################
                            #     Compile For Working      #
                            ################################
                            WRK_OUT_MEM_Path="wrk_out.out"

                            cp ${file} program.mem

                            echo -e   "${reset}Running Working...${reset}"
                            text=$( ./simv | tee  >(grep @@@ > ${WRK_OUT_MEM_Path}) | grep "CPI" )
                            echo -e   "${text}"
                            cycles=$(echo "$text" | cut -d' ' -f3)
                            instr=$(echo "$text" | cut -d' ' -f6)
                            branchDat=$(echo "$text" | cut -d' ' -f11)
                            icache=$(echo "$text" | cut -d' ' -f12)
                            dcache=$(echo "$text" | cut -d' ' -f13)
                            robHzrd=$(echo "$text" | cut -d' ' -f14)
                            rsHzrd=$(echo "$text" | cut -d' ' -f15)
                            lsqHzrd=$(echo "$text" | cut -d' ' -f16)

                            echo -n "${reset}Checking Memory Ouput...${reset}"
                            echo $(diff -y "${STD_OUT_MEM_Path}" "${WRK_OUT_MEM_Path}")

                            echo -e
                            echo "$N, ${ROB}, ${RS}, ${CACHE}, ${LATENCY}, ${BRANCH}, $unrolls, $cycles, $instr, $branchDat, $icache, $dcache, $robHzrd, $rsHzrd, $lsqHzrd" >> ${stats_fn}
                        done
                    done
                done
            done
        done
    done
done
date