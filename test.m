#import "JAValueToString.h"
#import <complex.h>
#import <CoreGraphics/CoreGraphics.h>


typedef int(*MyFunc)(CGRect r);
typedef int(^MyBlock)(CGRect r);


#if defined(__has_feature) && __has_feature(objc_arc)
#define USING_ARC				1
#define AUTORELEASE_ENTER		@autoreleasepool {
#define AUTORELEASE_EXIT		}
#else
#define USING_ARC				0
#define AUTORELEASE_ENTER		{ NSAutoreleasePool *autoreleasePool__ = [NSAutoreleasePool new];
#define AUTORELEASE_EXIT		[autoreleasePool__ drain]; }
#endif


typedef union MyUnion
{
	double b[6];
	CGRect a;
} MyUnion;


typedef struct MyStruct
{
	char c2;
	complex double x;
	unsigned char y;
	_Bool flag;
#if !USING_ARC
	NSString *s;
#endif
	Class cls;
	const char * const str;
	int * a;
	void *v;
	CGRect *r;
	CGRect r2;
	short saf;
	struct { int a; } anon;
	struct { float a; } *anonp;
	SEL ector;
	int array[5];
	MyUnion uni;
	MyFunc fu;
#if !USING_ARC
	MyBlock bl;
#endif
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
	AUTORELEASE_ENTER
	
	CGRect r = { 1, 2, 3, 4 };
	int a = 42;
	MyUnion u = { .a = r };
	
	MyStruct testCase =
	{
		.c2 = 'A',
		.x = 6 + 8 * _Complex_I,
		.y = '7',
		.flag = false,
#if !USING_ARC
		.s = @"an NSString",
#endif
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
	
	AUTORELEASE_EXIT
	return 0;
}
