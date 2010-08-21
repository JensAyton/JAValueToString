/*
	JAValueToString.m
	
	
	Copyright (C) 2010 Jens Ayton

	Permission is hereby granted, free of charge, to any person obtaining a
	copy of this software and associated documentation files (the "Software"),
	to deal in the Software without restriction, including without limitation
	the rights to use, copy, modify, merge, publish, distribute, sublicense,
	and/or sell copies of the Software, and to permit persons to whom the
	Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
	THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
	DEALINGS IN THE SOFTWARE.
*/

#import <Foundation/Foundation.h>


// If nonzero, each value is preceeded by a type name in parentheses.
#define INCLUDE_TYPE_NAMES		( 0 )

// Like INCLUDE_TYPE_NAMES, but for structs and unions (which have embedded names).
// Even if 0, names will be included for pointers to named structs (because the pointee content structure isn't encoded).
#define INCLUDE_STRUCT_NAMES	( 0	|| INCLUDE_TYPE_NAMES)

// If nonzero, chars are printed as text (if printable).
#define INCLUDE_CHARS			( 1 )

// If nonzero, pointer values are printed before the value of the pointee, in brackets.
#define INCLUDE_POINTERS		( 0 )

// If nonzero, the number of elements is printed before an array.
#define INCLUDE_ARRAY_COUNTS	( 1 )

// If nonzero, each interpretation of a union is printed, instead of just the first one.
#define INCLUDE_ALL_UNION_INFO	( 0 )

// If nonzero, the encoding string is included along with the decoded data.
#define INCLUDE_RAW_ENCODING	( 0 )


/*	Instead of actually printing decoded data, print the sorted order for the
	dispatch table so that bsort will work.
*/
#define SORT_DISPATCH_TABLE		( 0 )

#if JAENCODE_DEBUG
#define NAMES_IN_DISPATCH_TABLE		1
#else
#define NAMES_IN_DISPATCH_TABLE		SORT_DISPATCH_TABLE
#endif


static NSString * const kJAValueToStringParseError = @"se.ayton.jens.JAValueToString parse error";


enum
{
	/*	NOTE: you might think the __alignof__ operator could do this for us.
		
		You'd be wrong.
	*/
	
#if __x86_64__
	kAlignPointer			= 8,
	kAlignBool				= 1,
	kAlignChar				= 1,
	kAlignUnsignedChar		= 1,
	kAlignShort				= 2,
	kAlignUnsignedShort		= 2,
	kAlignInt				= 4,
	kAlignUnsignedInt		= 4,
	kAlignLong				= 8,
	kAlignUnsignedLong		= 8,
	kAlignLongLong			= 8,
	kAlignUnsignedLongLong	= 8,
	kAlignFloat				= 4,
	kAlignDouble			= 8,
	kAlignSelector			= 8,
#elif __i386__
	kAlignPointer			= 4,
	
	kAlignBool				= 1,
	kAlignChar				= 1,
	kAlignUnsignedChar		= 1,
	kAlignShort				= 2,
	kAlignUnsignedShort		= 2,
	kAlignInt				= 4,
	kAlignUnsignedInt		= 4,
	kAlignLong				= 4,
	kAlignUnsignedLong		= 4,
	kAlignLongLong			= 4,
	kAlignUnsignedLongLong	= 4,
	kAlignFloat				= 4,
	kAlignDouble			= 4,
	kAlignSelector			= 4,
#elif __ppc__
	kAlignPointer			= 4,
	kAlignBool				= 4,	// Sneaky!
	kAlignChar				= 1,
	kAlignUnsignedChar		= 1,
	kAlignShort				= 2,
	kAlignUnsignedShort		= 2,
	kAlignInt				= 4,
	kAlignUnsignedInt		= 4,
	kAlignLong				= 4,
	kAlignUnsignedLong		= 4,
	kAlignLongLong			= 4,
	kAlignUnsignedLongLong	= 4,
	kAlignFloat				= 4,
	kAlignDouble			= 4,
	kAlignSelector			= 4,
#else
#error Unknown architecture
#endif
	
	kAlignCharPointer		= kAlignPointer,
	kAlignObject			= kAlignPointer,
	kAlignClass				= kAlignObject,
	
	// Aggregates don't need alignment, as their first element will be aligned.
	kAlignStruct			= 1,
	kAlignArray				= 1,
	kAlignUnion				= 1,
	
	kAlignVoid				= 1,
	kAlignUndef				= 1,
	
	/*	The only information I can find about _C_ATOM is that it is int-sized
		in Apple's runtimes.
	*/
	kAlignAtom				= kAlignInt,
	
	//	Unsupported.
	kAlignBitfield			= 1
};


#define DO_NOTHING					do {} while (0)


#define ASSERT_NOT_END_OF_ENCODING(enc, curs)  do { if (enc[*curs] == '\0')  [NSException raise:kJAValueToStringParseError format:@"format string ended unexpectedly: \"%s\"", enc]; } while (0)
#if INCLUDE_TYPE_NAMES
#define TYPE_NAME(string, name)		[string appendFormat:@"(%@)", name]
#else
#define TYPE_NAME(string, name)		DO_NOTHING
#endif


#define DECODER_PARAMS const char * const encoding, size_t * const encOffset, const uint8_t * const buffer, size_t * const bufOffset, NSMutableString *string, size_t * const maxAlign
#define DECODER_CALL_THROUGH encoding, encOffset, buffer, bufOffset, string, maxAlign

static void DecodeValue(DECODER_PARAMS, BOOL align);


typedef void (*Decoder)(DECODER_PARAMS);


typedef struct
{
	Decoder		decoder;
	unsigned	alignment;
	const char	*signature;	// A char would be more efficient, but using a char * allows us to init with @encode().
#if NAMES_IN_DISPATCH_TABLE
	const char	*name;
#endif
} DispatchEntry;


#if NAMES_IN_DISPATCH_TABLE
#define DECLARE_DISPATCH(nm, sig) \
	static DispatchEntry sDispatch##nm = { .decoder = Decode##nm, .alignment = kAlign##nm, .signature = sig, .name = #nm }
#else
#define DECLARE_DISPATCH(name, sig) \
	static DispatchEntry sDispatch##name = { .decoder = Decode##name, .alignment = kAlign##name, .signature = sig }
#endif

#define DECLARE_DISPATCH_T(name, TYPE) \
DECLARE_DISPATCH(name, @encode(TYPE))

#define DECODE_SCALAR_BASE(TYPE, name, formatString, EXTRA, signature) \
static void Decode##name(DECODER_PARAMS) \
{ \
	NSCParameterAssert(bufOffset != NULL); \
	TYPE_NAME(string, @#TYPE); \
	TYPE value; \
	if (buffer != NULL) \
	{ \
		value = *((const TYPE *)(buffer + *bufOffset)); \
		[string appendFormat:formatString, value]; \
		EXTRA; \
	} \
	else \
	{ \
		[string appendString:@"null"]; \
	} \
	*bufOffset += sizeof value; \
} \
DECLARE_DISPATCH(name, signature);

#define DECODE_SCALAR(TYPE, name, formatString) DECODE_SCALAR_BASE(TYPE, name, formatString, DO_NOTHING, @encode(TYPE))


#if INCLUDE_CHARS
// Print ASCII printable chars or names.
static void AppendIfPrintableChar(unsigned char c, NSMutableString *string)
{
	if (c > 127 || c == 0)  return;
	
	const char *lowNames[] =
	{
		"NUL", "SOH", "STX", "ETX", "EOT", "ENQ", "ACK", "BEL", "BS", "tab",
		"LF", "VT", "FF", "CR", "SO", "SI", "DLE", "DC1", "DC2", "DC3", "DC4",
		"NAK", "SYN", "ETB", "CAN", "EM", "SUB", "ESC", "FS", "GS", "RS", "US",
		"space"
	};
	
	if (c < (sizeof(lowNames) / sizeof(*lowNames)))
	{
		[string appendFormat:@" (=%s)", lowNames[c]];
		return;
	}
	
	if (c == 127)
	{
		[string appendString:@" (=DEL)"];
		return;
	}
	
	[string appendFormat:@" (='%c')", c];
}


static BOOL IsPrintableMacRoman(unsigned char c)
{
	// Tab, CR, LF and NBSP deliberately excluded, along with various printing glyphs not likely to occur in FCCs.
	if (c < 32)  return NO;
	if (c == 127)  return NO;
	if (c >= 160 && c <= 173)  return NO;
	if (c >= 194 && c <= 202)  return NO;
	if (c >= 208 && c <= 215)  return NO;
	if (c >= 218 && c <= 221)  return NO;
	if (c >= 246)  return NO;
	
	return YES;
}


static void AppendIfPrintableFCC(unsigned val, NSMutableString *string)
{
	/*	Print MacRoman fourcharcodes, if and only if all four chars pass
		IsPrintableMacRoman() and at least one passes isalnum().
	*/
	unsigned char bytes[4] = { (val >> 24) & 0xFF, (val >> 16) & 0xFF, (val >> 8) & 0xFF, val & 0xFF };
	BOOL haveAlnum = NO;
	for (unsigned i = 0; i < 4; i++)
	{
		if (!IsPrintableMacRoman(bytes[i]))  return;
		if (isalnum(bytes[i]))  haveAlnum = YES;
	}
	if (!haveAlnum)  return;
	
	NSString *fcc = [[[NSString alloc] initWithBytes:bytes length:4 encoding:NSMacOSRomanStringEncoding] autorelease];
	[string appendFormat:@" (='%@')", fcc];
}


#if LONG_MAX == INT_MAX
#define AppendIfPrintableFCCLong AppendIfPrintableFCC
#else
#define AppendIfPrintableFCCLong(v, string)	DO_NOTHING
#endif


#else
#define AppendIfPrintableChar(c, string)	DO_NOTHING
#define AppendIfPrintableFCC(v, string)		DO_NOTHING
#endif

DECODE_SCALAR(short, Short, @"%i")
DECODE_SCALAR(unsigned short, UnsignedShort, @"%u")
DECODE_SCALAR_BASE(int, Int, @"%i", AppendIfPrintableFCC(value, string), @encode(int))
DECODE_SCALAR_BASE(unsigned int, UnsignedInt, @"%i", AppendIfPrintableFCC(value, string), @encode(unsigned int))
DECODE_SCALAR(long long, LongLong, @"%lli")
DECODE_SCALAR(unsigned long long, UnsignedLongLong, @"%llu")

DECODE_SCALAR_BASE(char, Char, @"%i", AppendIfPrintableChar(value, string), @encode(char))
DECODE_SCALAR_BASE(unsigned char, UnsignedChar, @"%u", AppendIfPrintableChar(value, string), @encode(unsigned char))

/*
	In 64-bit, @encode([unsigned] long) gives you q/Q, but we want to be able
	to handle l/L in case we come across them for some weird reason.
*/
DECODE_SCALAR_BASE(long, Long, @"%li", AppendIfPrintableFCCLong(value, string), "l")
DECODE_SCALAR_BASE(unsigned long, UnsignedLong, @"%lu", AppendIfPrintableFCCLong(value, string), "L")

DECODE_SCALAR(float, Float, @"%g")
DECODE_SCALAR(double, Double, @"%g")


static void DecodeBool(DECODER_PARAMS)
{
	NSCParameterAssert(bufOffset != NULL);
	
	// C _Bool/bool; unfortunately not BOOL.
	
	TYPE_NAME(string, @"bool");
	_Bool value;
	if (buffer != NULL)
	{
		value = *((const _Bool *)(buffer + *bufOffset));
		[string appendString:value ? @"true" : @"false"];
	}
	else
	{
		[string appendString:@"null"];
	}
	*bufOffset += sizeof(value);
}

DECLARE_DISPATCH_T(Bool, _Bool);


static void DecodeVoid(DECODER_PARAMS)
{
	// Can only occur as the target of a pointer.
	[string appendString:@"void"];
}

DECLARE_DISPATCH_T(Void, void);


static void DecodeUndef(DECODER_PARAMS)
{
	/*	Used for function pointers, reused in a silly way to handle blocks
		(see DecodeObject()), and possibly other cases.
	*/
	[string appendString:@"<unknown>"];
}

DECLARE_DISPATCH(Undef, "?");


static void DecodeObject(DECODER_PARAMS)
{
	NSCParameterAssert(encoding != NULL && encOffset != NULL);
	
	id value;
	
	/*	Special case: block references are encoded as "@?" (_C_ID, _C_UNDEF).
		Although blocks are indeed objects, their descriptions aren't useful.
	*/
	if (encoding[*encOffset] == '?')
	{
		(*encOffset)++;
		[string appendString:@"^block"];
	}
	else
	{
		TYPE_NAME(string, @"id");
		if (buffer != NULL)
		{
			value = *((const id *)(buffer + *bufOffset));
			
			if ([value isKindOfClass:[NSString class]])
			{
				// Quote strings.
				[string appendFormat:@"\"%@\"", value];
			}
			else
			{
				[string appendString:value ? [value description] : @"nil"];
			}
		}
		else
		{
			// Not nil - here null refers to the value of a pointer to an object pointer.
			[string appendString:@"null"];
		}
	}
	
	*bufOffset += sizeof value;
}

DECLARE_DISPATCH_T(Object, id);


static void DecodeClass(DECODER_PARAMS)
{
	NSCParameterAssert(bufOffset != NULL);
	
	TYPE_NAME(string, @"Class");
	Class value;
	if (buffer != NULL)
	{
		value = *((const Class *)(buffer + *bufOffset));
		
		[string appendFormat:@"class %@", value ? NSStringFromClass(value) : @"Nil"];
	}
	else
	{
		// Not Nil - here null refers to the value of a pointer to a class pointer.
		[string appendString:@"null"];
	}
	
	*bufOffset += sizeof value;
}

DECLARE_DISPATCH_T(Class, Class);


static void DecodeSelector(DECODER_PARAMS)
{
	NSCParameterAssert(bufOffset != NULL);
	
	TYPE_NAME(string, @"SEL");
	SEL value;
	if (buffer != NULL)
	{
		value = *((const SEL *)(buffer + *bufOffset));
		
		[string appendString:NSStringFromSelector(value)];
	}
	else
	{
		// Not Nil - here null refers to the value of a pointer to a class pointer.
		[string appendString:@"null"];
	}
	
	*bufOffset += sizeof value;
}

DECLARE_DISPATCH_T(Selector, SEL);


static void DecodeAtom(DECODER_PARAMS)
{
	NSCParameterAssert(bufOffset != NULL);
	
	// What's an atom? I have no idea, except that it's apparently int-sized.
	
	TYPE_NAME(string, @"atom");
	unsigned int value;
	if (buffer != NULL)
	{
		value = *((const unsigned int *)(buffer + *bufOffset));
#if !INCLUDE_TYPE_NAMES
		[string appendString:@"atom "];
#endif
		[string appendFormat:@"%#x", value];
	}
	else
	{
		[string appendString:@"null"];
	}
	*bufOffset += sizeof(value);
}

DECLARE_DISPATCH(Atom, "%");


static void DecodeStruct(DECODER_PARAMS)
{
	NSCParameterAssert(encoding != NULL && encOffset != NULL && bufOffset != NULL);
	
	/*	A struct with known contents is encoded as {Name} or {Name=<encoding>},
		where Name is a string (or ? if no name is known). <encoding> is a
		series of type encodings. For pointers to structs, the first form with
		no content encoding is used.
	*/
	
	size_t nameStart = *encOffset;
	
	while (encoding[*encOffset] != '=' && encoding[*encOffset] != '}')
	{
		(*encOffset)++;
		ASSERT_NOT_END_OF_ENCODING(encoding, encOffset);
	}
	
	// Pointers to structs don't encode struct layout.
	BOOL unknownStruct = encoding[*encOffset] == '}';
	
	NSString *name = nil;
	if (INCLUDE_STRUCT_NAMES || unknownStruct)
	{
		size_t nameLength = *encOffset - nameStart;
		if (nameLength != 1 || encoding[nameStart] != '\?')
		{
			name = [[NSString alloc] initWithBytes:encoding + nameStart
											length:nameLength
										  encoding:NSUTF8StringEncoding];
			[name autorelease];
		}
		if (name == nil)  name = @"<anonymous struct>";
	}
	
#if INCLUDE_STRUCT_NAMES
	[string appendFormat:@"(%@)", name];
#endif
	
	if (unknownStruct)
	{
#if INCLUDE_STRUCT_NAMES
		[string appendString:@"{...}"];
#else
		[string appendFormat:@"{%@...}", name];
#endif
	}
	else
	{
		// Skip the =.
		(*encOffset)++;
		
		ASSERT_NOT_END_OF_ENCODING(encoding, encOffset);
		
		[string appendString:@"{ "];
		BOOL first = YES;
		
		while (encoding[*encOffset] != '}')
		{
			if (!first)
			{
				[string appendString:@", "];
			}
			else
			{
				first = NO;
			}
			
			DecodeValue(DECODER_CALL_THROUGH, YES);
		}
		
		[string appendString:@" }"];
	}
	
	// Skip the }.
	(*encOffset)++;
}

DECLARE_DISPATCH(Struct, "{");


static inline NSString *ExtractString(const char *strPtr, size_t maxLength)
{
	if (strPtr == NULL || maxLength == 0)  return @"";
	
	size_t length = 0;
	while (length < maxLength && strPtr[length] != '\0')  length++;
	
	NSString *str = [[NSString alloc] initWithBytes:strPtr length:length encoding:NSUTF8StringEncoding];
	if (str == nil)
	{
		str = [[NSString alloc] initWithBytes:strPtr length:length encoding:[NSString defaultCStringEncoding]];
	}
	if (str == nil)
	{
		str = [[NSString alloc] initWithBytes:strPtr length:length encoding:NSISOLatin1StringEncoding];
	}
	
	return [str autorelease];
}


static void DecodeArray(DECODER_PARAMS)
{
	/*	An array is encoded as [<count><itemType>], where <count> is an
		unsigned decimal integer and <itemType> is a type encoding.
	*/
	NSCParameterAssert(encoding != NULL && encOffset != NULL && bufOffset != NULL);
	
	size_t count = 0;
	
	while (isdigit(encoding[*encOffset]))
	{
		count = count * 10 + encoding[*encOffset] - '0';
		(*encOffset)++;
		ASSERT_NOT_END_OF_ENCODING(encoding, encOffset);
	}
	
	// Find the ].
	size_t contentEncStart = *encOffset;
	while (encoding[*encOffset] != ']')
	{
		(*encOffset)++;
		ASSERT_NOT_END_OF_ENCODING(encoding, encOffset);
	}
	
#if INCLUDE_ARRAY_COUNTS
	[string appendFormat:@"(%zu)", count];
#endif
	
	if (*encOffset - contentEncStart == 1 && encoding[contentEncStart] == 'c')
	{
		// Special case to show char arrays as strings.
		if (buffer != NULL)
		{
			[string appendFormat:@"\"%@\"", ExtractString((const char *)buffer + *bufOffset, count)];
		}
		else
		{
			[string appendFormat:@"[null]"];
		}
		*bufOffset += count;
	}
	else
	{
		[string appendString:@"[ "];
		
		// Iterate over array contents.
		BOOL first = YES;
		for (size_t iter = 0; iter < count; iter++)
		{
			if (!first)
			{
				[string appendString:@", "];
			}
			else
			{
				first = NO;
			}
			
			size_t subEncoding = contentEncStart;
			DecodeValue(encoding, &subEncoding, buffer, bufOffset, string, maxAlign, YES);
		}
		
		[string appendString:@" ]"];
	}
	
	// Skip the ].
	(*encOffset)++;
}

DECLARE_DISPATCH(Array, "[");


static void DecodeUnion(DECODER_PARAMS)
{
	/*	Not very surprisingly, a union is laid out much like a struct, except
		that each type declaration refers to the same block of memory. In
		order to avoid misalignment in aggregates, we must advance by the
		length of the longest encoded type. This requires us to decode each
		element of the union.
		
		If INCLUDE_ALL_UNION_INFO is nonzero, we also print the content of
		each element. Otherwise, we just print the first "branch".
	*/
	
	NSCParameterAssert(encoding != NULL && encOffset != NULL && bufOffset != NULL);
	
	size_t nameStart = *encOffset;
	
	while (encoding[*encOffset] != '=' && encoding[*encOffset] != ')')
	{
		(*encOffset)++;
		ASSERT_NOT_END_OF_ENCODING(encoding, encOffset);
	}
	
	// Pointers to unions don't encode struct layout.
	BOOL unknownStruct = encoding[*encOffset] == ')';
	
	NSString *name = nil;
	if (INCLUDE_STRUCT_NAMES || unknownStruct)
	{
		size_t nameLength = *encOffset - nameStart;
		if (nameLength != 1 || encoding[nameStart] != '\?')
		{
			name = [[NSString alloc] initWithBytes:encoding + nameStart
											length:nameLength
										  encoding:NSUTF8StringEncoding];
			[name autorelease];
			name = [@"union " stringByAppendingString:name];
		}
		if (name == nil)  name = @"<anonymous union>";
	}
	
#if INCLUDE_STRUCT_NAMES
	[string appendFormat:@"(%@)", name];
#endif
	
	if (unknownStruct)
	{
#if INCLUDE_STRUCT_NAMES
		[string appendString:@"{...}"];
#else
		[string appendFormat:@"{%@...}", name];
#endif
	}
	else
	{
		// Skip the =.
		(*encOffset)++;
		
		ASSERT_NOT_END_OF_ENCODING(encoding, encOffset);
		
		[string appendString:@"{ "];
		BOOL first = YES;
		size_t start = *bufOffset;
		size_t end = start;
		NSMutableString *subString = string;
		
		while (encoding[*encOffset] != ')')
		{
			if (!first)
			{
				[subString appendString:@" == "];
			}
			else
			{
				first = NO;
			}
			
			size_t offset = start;
			DecodeValue(encoding, encOffset, buffer, &offset, subString, maxAlign, YES);
			if (offset > end)  end = offset;
			
#if !INCLUDE_ALL_UNION_INFO
			subString = nil;
#endif
		}
		
		*bufOffset = end;
		
		[string appendString:@" }"];
	}
	
	// Skip the ).
	(*encOffset)++;
}

DECLARE_DISPATCH(Union, "(");


static void DecodeCharPointer(DECODER_PARAMS)
{
	NSCParameterAssert(encoding != NULL && encOffset != NULL && bufOffset != NULL);
	
	const char *value = NULL;
	TYPE_NAME(string, @"char *");
	if (buffer != NULL)
	{
		value = *((const char **)(buffer + *bufOffset));
		[string appendFormat:@"\"%s\"", value];
	}
	else
	{
		[string appendString:@"null"];
	}
	*bufOffset += sizeof value;
}

DECLARE_DISPATCH_T(CharPointer, char *);


static void DecodePointer(DECODER_PARAMS)
{
	NSCParameterAssert(encoding != NULL && encOffset != NULL && bufOffset != NULL);
	
	if (encoding[*encOffset] == 'c')
	{
		(*encOffset)++;
		DecodeCharPointer(DECODER_CALL_THROUGH);
		return;
	}
	
	const void *value = NULL;
	if (buffer != NULL)
	{
		value = *((const void **)(buffer + *bufOffset));
	}
	*bufOffset += sizeof value;
	
	[string appendString:@"&"];
#if INCLUDE_POINTERS
	[string appendFormat:@"[%p]", value];
#endif
	
	size_t subBufOffset = 0;
	// Even if pointer is NULL, we need to continue parsing the encoding string if we're in an aggregate.
	DecodeValue(encoding, encOffset, (const uint8_t *)value, &subBufOffset, string, maxAlign, NO);
}

DECLARE_DISPATCH(Pointer, "^");


static void DecodeBitfield(DECODER_PARAMS)
{
	[NSException raise:kJAValueToStringParseError format:@"bitfields are not supported"];
}

DECLARE_DISPATCH(Bitfield, "b");


static const DispatchEntry *sDispatchTable[] =
{
	/*	NOTE: these must be listed in lexicographic order by signature. To
		generate the proper order, run with SORT_DISPATCH_TABLE defined.
	*/
	
	&sDispatchClass,
	&sDispatchAtom,
	&sDispatchUnion,
	&sDispatchCharPointer,
	&sDispatchSelector,
	&sDispatchUndef,
	&sDispatchObject,
	&sDispatchBool,
	&sDispatchUnsignedChar,
	&sDispatchUnsignedInt,
	&sDispatchUnsignedLong,
	&sDispatchUnsignedLongLong,
	&sDispatchUnsignedShort,
	&sDispatchArray,
	&sDispatchPointer,
	&sDispatchBitfield,
	&sDispatchChar,
	&sDispatchDouble,
	&sDispatchFloat,
	&sDispatchInt,
	&sDispatchLong,
	&sDispatchLongLong,
	&sDispatchShort,
	&sDispatchVoid,
	&sDispatchStruct,
	
	/*	MISSING: _C_VECTOR, _C_CONST.
		I have no idea when, if ever, these are generated. (In particular, I
		expected vector to be generated for Altivec or SSE vector types
		-- vector float or __m128 -- but these are not encoded at all.)
	*/
};


enum
{
	kDispatchTableSize = sizeof sDispatchTable / sizeof *sDispatchTable
};


static int CompareDispatchEntries(const DispatchEntry **a, const DispatchEntry **b)
{
	return (*a)->signature[0] - (*b)->signature[0];
}


static inline size_t RoundUp(size_t size, size_t factor)
{
	size += factor - 1;
	size -= size % factor;
	return size;
}


static void DecodeValue(DECODER_PARAMS, BOOL align)
{
	NSCParameterAssert(encoding != NULL && encOffset != NULL && bufOffset != NULL && maxAlign != NULL);
	
	char signature = encoding[*encOffset];
	
	DispatchEntry template = { .signature = encoding + *encOffset };
	DispatchEntry *searchKey = &template;
	(*encOffset)++;
	
	DispatchEntry *dispatch = *(DispatchEntry **)bsearch(&searchKey, sDispatchTable, kDispatchTableSize, sizeof *sDispatchTable, (int(*)(const void *, const void *))CompareDispatchEntries);
	
	if (dispatch != NULL)
	{
		if (align)
		{
			*bufOffset = RoundUp(*bufOffset, dispatch->alignment);
			*maxAlign = MAX(*maxAlign, dispatch->alignment);
		}
		dispatch->decoder(DECODER_CALL_THROUGH);
		return;
	}
	
	[NSException raise:kJAValueToStringParseError format:@"unknown type code '%c' in encoding string \"%s\"", signature, encoding];
	
	(*encOffset)++;
}


#if SORT_DISPATCH_TABLE
static void SortDispatchTable(void)
{
	qsort(sDispatchTable, kDispatchTableSize, sizeof *sDispatchTable, (int(*)(const void *, const void *))CompareDispatchEntries);
	
	for (unsigned i = 0; i < kDispatchTableSize; i++)
	{
		printf("\t&sDispatch%s,\n", sDispatchTable[i]->name);
	}
}
#elif JAENCODE_DEBUG
static void AssertDispatchTableSorted(void)
{
	for (unsigned i = 1; i < kDispatchTableSize; i++)
	{
		NSCAssert(CompareDispatchEntries(&sDispatchTable[i - 1], &sDispatchTable[i]) < 0, @"Dispatch table is not sorted. Run with SORT_DISPATCH_TABLE set to 1 to find correct sort order.");
	}
}
#endif



NSString *JAValueToString(const char *encoding, const void *value, size_t expectedSize)
{
#if SORT_DISPATCH_TABLE
	SortDispatchTable();
	return nil;
#else
#if JAENCODE_DEBUG
	AssertDispatchTableSorted();
#endif
	
	if (encoding == NULL || encoding[0] == '\0' || value == NULL)  return nil;
	
	NSMutableString *result = [NSMutableString string];
#if INCLUDE_RAW_ENCODING
	[result appendFormat:@"%s :: ", encoding];
#endif
	
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	const uint8_t *buffer = value;
	size_t encOffset = 0;
	size_t bufOffset = 0;
	size_t maxAlign = 1;
	
	@try
	{
		if (expectedSize != 0)
		{
			/*	If a size expectation is specified, verify out parsing by first
				parsing for size only (no reading or writing) and verifying that
				the parsed size matches expectations.
			*/
			
			DecodeValue(encoding, &encOffset, NULL, &bufOffset, nil, &maxAlign, NO);
			
			size_t parsedSize = RoundUp(bufOffset, maxAlign);
			if (parsedSize == expectedSize)
			{
				encOffset = 0;
				bufOffset = 0;
				DecodeValue(encoding, &encOffset, buffer, &bufOffset, result, &maxAlign, NO);
			}
			else
			{
				[result appendFormat:@"<Decoding failed - actual size is %zu bytes, but parsed size is %zu bytes>", expectedSize, parsedSize];
			}
		}
		else
		{
			//	No expected size, live dangerously.
			DecodeValue(encoding, &encOffset, buffer, &bufOffset, result, &maxAlign, NO);
		}
	}
	@catch (NSException *e)
	{
		if ([[e name] isEqualToString:kJAValueToStringParseError])
		{
			[result setString:@""];
			[result appendFormat:@"<Decoding failed - %@>", [e reason]];
		}
		else
		{
			[e raise];
		}
	}
	
	[pool drain];
	
	return result;
	
#endif
}
