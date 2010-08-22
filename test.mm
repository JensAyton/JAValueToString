#import "JAValueToString.h"
#import <complex>


class TestClass
{
	std::complex<double> complex;
	int integer;
	
public:
	/*	Note: having a virtual method means there's a vtable, which is encoded
		as "^^?" and displayed as "&&<unknown>".
	*/
	virtual ~TestClass() {};
};


int main (int argc, const char * argv[])
{
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	TestClass testCase;
	JA_DUMP(testCase);
	
	NSLog(@"Done.");
	
	[pool drain];
	return 0;
}
