void append(ulong &v[], ulong x)
{
	int size = ArraySize(v);
	ArrayResize(v, size+1);
	v[size] = x;
}

void append(double &v[], double x)
{
	int size = ArraySize(v);
	ArrayResize(v, size+1);
	v[size] = x;
}