#import "JAValueToString.h"
#import <complex>


class TestClass
{
	std::complex<double> complex;
	int integer;
	
public:
	/*	Note: having a virtual method means there's a vtable, which is encoded
		as "^^?" and displayed as "<vtable 0x...>".
	*/
	virtual ~TestClass() {};
};


int main (int argc, const char * argv[])
{
	@autoreleasepool
	{
		TestClass testCase;
		JA_DUMP(testCase);
		
		NSLog(@"Done.");
	}
	return 0;
}
