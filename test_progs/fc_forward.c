#define N 12

int n = N;
int seed = 0x720f8a4;
int out;

void kernel(int  vec_a[n],int  vec_b[n], int result[n], int b, int *out) { 
	int i = 0, j = 0, k = 0;  
	int dot = 0;
	//multiply and acc
	for (i = 0; i < n; ++i) {
		result[i] = vec_a[i] * vec_b[i];
		dot += result[i];
	}
	*out = dot + b;
}

int myRand() {
    int a = 16807;
    int m = 2147483647;
    seed = (a * seed) % m;
}

int main() {
	int x[n], W[n], inner[n];
	int b;
	//initializing weights
	for (int i = 0; i < n; ++i) {
		x[i] = myRand() & ((1 << 16) - 1);
		W[i] = myRand() & ((1 << 16) - 1);
		inner[i] = 0;
	}
	b = myRand();
	//the actual layer
	kernel(x,W,inner,b, &out);
    if (out == 0) {
        return 1;
    }
	return 0;
}
