/*
	FindAlignment.c
	
	Simple tool to build the alignment enum for JAValueToString.
*/

#import <stdio.h>
#import <stddef.h>
#import <objc/runtime.h>


#define FIND_ALIGNMENT(NAME, TYPE)  printf("\tkAlign%s\t=%zu,\n", #NAME, offsetof(struct{char oddifier; TYPE target;}, target), __alignof__(TYPE))


int main (int argc, const char * argv[])
{
	FIND_ALIGNMENT(Pointer, void *);
//	FIND_ALIGNMENT(CharPointer, char *);
	FIND_ALIGNMENT(Bool, _Bool);
	FIND_ALIGNMENT(Char, char);
	FIND_ALIGNMENT(UnsignedChar, unsigned char);
	FIND_ALIGNMENT(Short, short);
	FIND_ALIGNMENT(UnsignedShort, unsigned short);
	FIND_ALIGNMENT(Int, int);
	FIND_ALIGNMENT(UnsignedInt, unsigned int);
	FIND_ALIGNMENT(Long, long);
	FIND_ALIGNMENT(UnsignedLong, unsigned long);
	FIND_ALIGNMENT(LongLong, long long);
	FIND_ALIGNMENT(UnsignedLongLong, unsigned long long);
	FIND_ALIGNMENT(Float, float);
	FIND_ALIGNMENT(Double, double);
//	FIND_ALIGNMENT(Object, id);
//	FIND_ALIGNMENT(Class, Class);
	FIND_ALIGNMENT(Selector, SEL);
	
	return 0;
}
