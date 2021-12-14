int min(int a,int b,int c){
    int temp;
    temp = a<b?a:b;
    temp = temp<c?temp:c;
    return temp;
}

int strlen(char* word) {
    int i;
    for (i = 0; word[i] != '\0'; i++);
    return i;
}

int minDistance(char* word1, char* word2) {
    
    int len1=strlen(word1),len2=strlen(word2);
    int table[len1+1][len2+1],i,j;
    
    for(i=0;i<=len1;i++)
        table[i][0] = i;
    for(j=0;j<=len2;j++)
        table[0][j] = j;
    
    for(i=0;i<len1;i++){
        for(j=0;j<len2;j++){
            if(word1[i]!=word2[j])
                table[i+1][j+1] = 1+min(table[i][j+1],table[i+1][j],table[i][j]); // i,j i,j+1, j+1,i
            else 
                table[i+1][j+1] = table[i][j];
        }
    }
 return table[len1][len2];
}

int main() {
    minDistance("racketeering", "electroencephalographies");
    return 0;
}