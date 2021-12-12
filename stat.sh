
make clean &> /dev/null
#make program SOURCE=test_progs/bfs.c &> /dev/null
touch stats.csv
echo "N,ROB,RS,PREDBITS,BTBLINES" > stats.csv

for N in $(seq 3 3)
do
    for ROB in $(seq 32 8 32)
    do
        for RS in $(seq 16 2 16)
        do
            for PREDBITS in $(seq 2 2 12)
            do
                for BTBLINES in 8
                do
                    count=0
                    totalcpi=0
                    cp sys_defs_stat_copy.txt sys_defs.svh
                    sed -i "s/@N@/$N/g" sys_defs.svh
                    sed -i "s/@ROB@/$ROB/g" sys_defs.svh
                    sed -i "s/@RS@/$RS/g" sys_defs.svh
                    sed -i "s/@PREDBITS@/$PREDBITS/g" sys_defs.svh
                    sed -i "s/@BTBLINES@/$BTBLINES/g" sys_defs.svh

                    make simv &> /dev/null
                    for file in sort_search
                    do 
                        echo "$file"
                        make program SOURCE="test_progs/$file.c" &> /dev/null
                        CPI="$(./simv | grep "CPI" | cut -d' ' -f9)"
                        totalcpi="$(echo "$totalcpi+$CPI" | bc)"
                        echo $CPI
                        count="$(echo "$count+1" | bc)"
                        #echo "$CPI" >> stats.csv
                    done
                    avgcpi="$(echo "scale=5 ;$totalcpi / $count" | bc -l)"
                    echo "$N,$ROB,$RS,$PREDBITS,$BTBLINES,$avgcpi" >> stats.csv
                    #echo "CPI: $totalcpi Number of tests= $count"
                done
            done
        done
    done
done

