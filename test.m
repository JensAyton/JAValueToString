#import "JAValueToString.h"
#import <complex.h>


typedef int(*MyFunc)(NSRect r);
typedef int(^MyBlock)(NSRect r);


typedef union MyUnion
{
	double b[6];
	NSRect a;
} MyUnion;


typedef struct MyStruct
{
	char c2;
	complex double x;
	unsigned char y;
	_Bool flag;
	NSString *s;
	Class cls;
	const char * const str;
	int * a;
	void *v;
	NSRect *r;
	NSRect r2;
	short saf;
	struct { int a; } anon;
	struct { float a; } *anonp;
	SEL ector;
	int array[5];
	MyUnion uni;
	MyFunc fu;
	MyBlock bl;
	int fcc;
} MyStruct;


typedef struct MyStruct2
{
	short a;
	short c;
	char b;
} MyStruct2;


int main (int argc, const char * argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSRect r = NSMakeRect(1, 2, 3, 4);
	int a = 42;
	MyUnion u = { .a = r };
	
	MyStruct testCase =
	{
		.c2 = 'A',
		.x = 6 + 8 * _Complex_I,
		.y = '7',
		.flag = false,
		.s = @"an NSString",
		.cls = [NSArray class],
		.str = "a C string",
		.a = &a,
		.v = &a,
		.r = &r,
		.r2 = r,
		.saf = 123,
		.ector = @selector(substringFromIndex:),
		.uni = u,
		.fcc = 'aFCC'
	};
	JA_DUMP(testCase);
	
	/*	Test case for size calculations.
		
		The parser will find this to be 7 bytes long, but the "expected size"
		from sizeof is rounded up to a multiple of the largest aligment of any
		element. This case should be handled properly by JAValueToString().
	*/
	MyStruct2 alignmentTest = {0};
	JA_DUMP(alignmentTest);
	
	int integer = 768;
	JA_DUMP(integer);
	
	const char *string = "This am an string.";
	JA_DUMP(string);
	
	JA_DUMP("This, too, is a string.");
	
	complex double complexDouble = 1 - 2 * _Complex_I;
	JA_DUMP(complexDouble);
	
	/*	Previous failure case: calculation of alignment is dependent on the
		highest-alignment field of the inner struct, i.e. c.
	*/
	struct NestedAlignmentTest
	{
		int16_t			a;
		struct
		{
			int16_t		b;
			int64_t		c;
		}				s;
	} nestedAlignmentTest = { 1, { 2, 3 } };
	JA_DUMP(nestedAlignmentTest);
	
	// Known failure case: bitfields are not supported.
	struct BitfieldTest
	{
		int bitfield: 4;
	} bitfieldTestFAIL;
	JA_DUMP(bitfieldTestFAIL);
	
	NSLog(@"Done.");
	
	[pool drain];
	return 0;
}
