//
//  SSZipArchiveTests.m
//  SSZipArchiveTests
//
//  Created by Sam Soffes on 10/3/11.
//  Copyright (c) 2011-2014 Sam Soffes. All rights reserved.
//

#import <SSZipArchive/SSZipArchive.h>
#import <XCTest/XCTest.h>
#import <CommonCrypto/CommonDigest.h>

#import "CollectingDelegate.h"

@interface CancelDelegate : NSObject <SSZipArchiveDelegate>
@property (nonatomic, assign) NSInteger numFilesUnzipped;
@property (nonatomic, assign) NSInteger numFilesToUnzip;
@property (nonatomic, assign) BOOL didUnzipArchive;
@property (nonatomic, assign) NSInteger loaded;
@property (nonatomic, assign) NSInteger total;
@end

@implementation CancelDelegate
- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo
{
    _numFilesUnzipped = fileIndex + 1;
}
- (BOOL)zipArchiveShouldUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo
{
    //return YES;
    return _numFilesUnzipped < _numFilesToUnzip;
}
- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPath
{
    _didUnzipArchive = YES;
}
- (void)zipArchiveProgressEvent:(unsigned long long)loaded total:(unsigned long long)total
{
    _loaded = (NSInteger)loaded;
    _total = (NSInteger)total;
}
@end

@interface SSZipArchiveTests : XCTestCase <SSZipArchiveDelegate>
@end

@implementation SSZipArchiveTests {
    NSMutableArray *progressEvents;
}

- (void)setUp {
    [super setUp];
    progressEvents = [NSMutableArray array];
}

- (void)tearDown {
    [super tearDown];
    [[NSFileManager defaultManager] removeItemAtPath:[self _cachesPath:nil] error:nil];
}


- (void)testZipping {
    // use extracted files from [-testUnzipping]
    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"],
                            [inputPath stringByAppendingPathComponent:@"LICENSE"]];

    NSString *outputPath = [self _cachesPath:@"Zipped"];

    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];
    [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths];

    // TODO: Make sure the files are actually unzipped. They are, but the test should be better.
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Archive created");
}


- (void)testDirectoryZipping {
    // use Unicode as folder (has a file in root and a file in subfolder)
    NSString *inputPath = [self _cachesPath:@"Unicode"];

    NSString *outputPath = [self _cachesPath:@"FolderZipped"];
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"ArchiveWithFolders.zip"];

    [SSZipArchive createZipFileAtPath:archivePath withContentsOfDirectory:inputPath];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:archivePath], @"Folder Archive created");
}

- (void)testMultipleZippping{
    NSArray *inputPaths = @[[[NSBundle bundleForClass: [self class]]pathForResource:@"0" ofType:@"m4a"],

                            [[NSBundle bundleForClass: [self class]]pathForResource:@"1" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"2" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"3" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"4" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"5" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"6" ofType:@"m4a"],
                            [[NSBundle bundleForClass: [self class]]pathForResource:@"7" ofType:@"m4a"]
                            ];
    NSString *outputPath = [self _cachesPath:@"Zipped"];

    // this is a monster
    // if testing on iOS, within 30 loops it will fail; however, on OS X, it may take about 900 loops
    for (int test = 0; test < 20; test++)
    {
        // Zipping
        NSString *archivePath = [outputPath stringByAppendingPathComponent:[NSString stringWithFormat:@"queue_test_%d.zip",test]];

        [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths];

        long long threshold = 510000; // 510kB:size slightly smaller than a successful zip, but much larger than a failed one
        long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:archivePath error:nil][NSFileSize] longLongValue];
        XCTAssertTrue(fileSize > threshold, @"zipping failed at %@!",archivePath);
    }

}

- (void)testUnzipping {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Regular"];

    [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:self];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");

    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}
- (void)testSmallFileUnzipping {
    NSString *zipPath = [[NSBundle bundleForClass: [self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Regular"];

    [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:self];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");

    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}
- (void)testUnzippingProgress {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Progress"];

    [progressEvents removeAllObjects];

    [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:self];

    // 4 events: the first, then for each of the two files one, then the final event
    XCTAssertTrue(4 == [progressEvents count], @"Expected 4 progress events");
    XCTAssertTrue(0 == [progressEvents[0] intValue]);
    XCTAssertTrue(619 == [progressEvents[1] intValue]);
    XCTAssertTrue(1114 == [progressEvents[2] intValue]);
    XCTAssertTrue(1436 == [progressEvents[3] intValue]);
}


- (void)testUnzippingWithPassword {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestPasswordArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Password"];

    NSError *error = nil;
    [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath overwrite:YES password:@"passw0rd" error:&error delegate:self];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *testPath = [outputPath stringByAppendingPathComponent:@"Readme.markdown"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"Readme unzipped");

    testPath = [outputPath stringByAppendingPathComponent:@"LICENSE"];
    XCTAssertTrue([fileManager fileExistsAtPath:testPath], @"LICENSE unzipped");
}


- (void)testUnzippingTruncatedFileFix {
    NSString* zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"IncorrectHeaders" ofType:@"zip"];
    NSString* outputPath = [self _cachesPath:@"IncorrectHeaders"];

    [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:self];

    NSString* intendedReadmeTxtMD5 = @"31ac96301302eb388070c827447290b5";

    NSString* filePath = [outputPath stringByAppendingPathComponent:@"IncorrectHeaders/Readme.txt"];
    NSData* data = [NSData dataWithContentsOfFile:filePath];

    NSString* actualReadmeTxtMD5 = [self _calculateMD5Digest:data];
    XCTAssertTrue([actualReadmeTxtMD5 isEqualToString:intendedReadmeTxtMD5], @"Readme.txt MD5 digest should match original.");
}


- (void)testUnzippingWithSymlinkedFileInside {

    NSString* zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"SymbolicLink" ofType:@"zip"];
    NSString* outputPath = [self _cachesPath:@"SymbolicLink"];

    [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:self];

    NSString *testSymlink = [outputPath stringByAppendingPathComponent:@"SymbolicLink/Xcode.app"];

    NSError *error = nil;
    NSDictionary *info = [[NSFileManager defaultManager] attributesOfItemAtPath: testSymlink error: &error];

    XCTAssertTrue(info, @"Symbolic links should persist from the original archive to the outputted files.");
}

- (void)testUnzippingWithRelativeSymlink {

    NSString *resourceName = @"RelativeSymbolicLink";
    NSString* zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:resourceName ofType:@"zip"];
    NSString* outputPath = [self _cachesPath:resourceName];

    [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:self];

    // Determine where the symlinks are
    NSString *subfolderName = @"symlinks";
    NSString *testBasePath = [NSString pathWithComponents:@[outputPath]];
    NSString *testSymlinkFolder = [NSString pathWithComponents:@[testBasePath, subfolderName, @"folderSymlink"]];
    NSString *testSymlinkFile = [NSString pathWithComponents:@[testBasePath, subfolderName, @"fileSymlink"]];

    BOOL found = [[NSFileManager defaultManager] attributesOfItemAtPath: testSymlinkFile error: nil];

    XCTAssertTrue(found, @"Relative symbolic links should persist from the original archive to the outputted files (and also remain relative).");

    found = [[NSFileManager defaultManager] attributesOfItemAtPath: testSymlinkFolder error: nil];

    XCTAssertTrue(found, @"Relative symbolic links should persist from the original archive to the outputted files (and also remain relative).");
}

- (void)testUnzippingWithUnicodeFilenameInside {

    NSString* zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Unicode" ofType:@"zip"];
    NSString* outputPath = [self _cachesPath:@"Unicode"];

    [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:self];

    bool unicodeFilenameWasExtracted = [[NSFileManager defaultManager] fileExistsAtPath:[outputPath stringByAppendingPathComponent:@"Accént.txt"]];

    bool unicodeFolderWasExtracted = [[NSFileManager defaultManager] fileExistsAtPath:[outputPath stringByAppendingPathComponent:@"Fólder/Nothing.txt"]];

    XCTAssertTrue(unicodeFilenameWasExtracted, @"Files with filenames in unicode should be extracted properly.");
    XCTAssertTrue(unicodeFolderWasExtracted, @"Folders with names in unicode should be extracted propertly.");
}


- (void)testZippingAndUnzippingForDate {

    NSString *inputPath = [self _cachesPath:@"Regular"];
    NSArray *inputPaths = @[[inputPath stringByAppendingPathComponent:@"Readme.markdown"]];

    NSDictionary *originalFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[inputPath stringByAppendingPathComponent:@"Readme.markdown"] error:nil];

    NSString *outputPath = [self _cachesPath:@"ZippedDate"];
    NSString *archivePath = [outputPath stringByAppendingPathComponent:@"CreatedArchive.zip"];

    [SSZipArchive createZipFileAtPath:archivePath withFilesAtPaths:inputPaths];
    [SSZipArchive unzipFileAtPath:archivePath toDestination:outputPath delegate:self];

    NSDictionary *createdFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[outputPath stringByAppendingPathComponent:@"Readme.markdown"] error:nil];

    XCTAssertEqualObjects(originalFileAttributes[NSFileCreationDate], createdFileAttributes[@"NSFileCreationDate"], @"Orginal file creationDate should match created one");
}


- (void)testZippingAndUnzippingForPermissions {
    // File we're going to test permissions on before and after zipping
    NSString *targetFile = @"/Contents/MacOS/TestProject";


    /********** Zipping ********/

    // The .app file we're going to zip up
    NSString *inputFile = [[NSBundle bundleForClass: [self class]] pathForResource:@"PermissionsTestApp" ofType:@"app"];

    // The path to the target file in the app before zipping
    NSString *targetFilePreZipPath = [inputFile stringByAppendingPathComponent:targetFile];

    // Atribtues for the target file before zipping
    NSDictionary *preZipAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:targetFilePreZipPath error:nil];

    // Directory to output our created zip file
    NSString *outputDir = [self _cachesPath:@"PermissionsTest"];
    // The path to where the archive shall be created
    NSString *archivePath = [outputDir stringByAppendingPathComponent:@"TestAppArchive.zip"];

    // Create the zip file using the contents of the .app file as the input
    [SSZipArchive createZipFileAtPath:archivePath withContentsOfDirectory:inputFile];


    /********** Un-zipping *******/

    // Using this newly created zip file, unzip it
    [SSZipArchive unzipFileAtPath:archivePath toDestination:outputDir];

    // Get the path to the target file after unzipping
    NSString *targetFilePath = [outputDir stringByAppendingPathComponent:@"/Contents/MacOS/TestProject"];

    // Get the file attributes of the target file following the unzipping
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:targetFilePath error:nil];

    // Compare the value of the permissions attribute to assert equality
    NSString *unzippedPerms = fileAttributes[NSFilePosixPermissions];
    NSString *prezippedPerms = preZipAttributes[NSFilePosixPermissions];
    XCTAssertEqualObjects(unzippedPerms, prezippedPerms, @"File permissions should be retained during compression and de-compression");
}

- (void)testUnzippingWithCancel {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Cancel1"];

    CancelDelegate *delegate = [[CancelDelegate alloc] init];
    delegate.numFilesToUnzip = 1;

    [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];

    XCTAssertEqual(delegate.numFilesUnzipped, 1);
    XCTAssertFalse(delegate.didUnzipArchive);
    XCTAssertNotEqual(delegate.loaded, delegate.total);

    outputPath = [self _cachesPath:@"Cancel2"];

    delegate = [[CancelDelegate alloc] init];
    delegate.numFilesToUnzip = 1000;

    [SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:delegate];

    XCTAssertEqual(delegate.numFilesUnzipped, 2);
    XCTAssertTrue(delegate.didUnzipArchive);
    XCTAssertEqual(delegate.loaded, delegate.total);

}

// Commented out to avoid checking in several gig file into the repository. Simply add a file named
// `LargeArchive.zip` to the project and uncomment out these lines to test.
//
//- (void)testUnzippingLargeFiles {
//	NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"LargeArchive" ofType:@"zip"];
//	NSString *outputPath = [self _cachesPath:@"Large"];
//
//	[SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath];
//}

-(void)testShouldProvidePathOfUnzippedFileInDelegateCallback {
    CollectingDelegate *collector = [CollectingDelegate new];
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestArchive" ofType:@"zip"];
   	NSString *outputPath = [self _cachesPath:@"Regular"];

   	[SSZipArchive unzipFileAtPath:zipPath toDestination:outputPath delegate:collector];

    //    STAssertEqualObjects([collector.files objectAtIndex:0], @"LICENSE.txt", nil);
    //    STAssertEqualObjects([collector.files objectAtIndex:1], @"README.md", nil);
}

#pragma mark - SSZipArchiveDelegate

- (void)zipArchiveWillUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo {
    NSLog(@"*** zipArchiveWillUnzipArchiveAtPath: `%@` zipInfo:", path);
}


- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPath {
    NSLog(@"*** zipArchiveDidUnzipArchiveAtPath: `%@` zipInfo: unzippedPath: `%@`", path, unzippedPath);
}

- (BOOL)zipArchiveShouldUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo
{
    NSLog(@"*** zipArchiveShouldUnzipFileAtIndex: `%zd` totalFiles: `%zd` archivePath: `%@` fileInfo:", fileIndex, totalFiles, archivePath);
    return YES;
}

- (void)zipArchiveWillUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo {
    NSLog(@"*** zipArchiveWillUnzipFileAtIndex: `%zd` totalFiles: `%zd` archivePath: `%@` fileInfo:", fileIndex, totalFiles, archivePath);
}


- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo {
    NSLog(@"*** zipArchiveDidUnzipFileAtIndex: `%zd` totalFiles: `%zd` archivePath: `%@` fileInfo:", fileIndex, totalFiles, archivePath);
}

- (void)zipArchiveProgressEvent:(unsigned long long)loaded total:(unsigned long long)total {
    NSLog(@"*** zipArchiveProgressEvent: loaded: `%zd` total: `%zd`", (NSInteger)loaded, (NSInteger)total);
    [progressEvents addObject:@(loaded)];
}


#pragma mark - Private

- (NSString *)_cachesPath:(NSString *)directory {
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
                      stringByAppendingPathComponent:@"com.samsoffes.ssziparchive.tests"];
    if (directory) {
        path = [path stringByAppendingPathComponent:directory];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }

    return path;
}


// Taken from https://github.com/samsoffes/sstoolkit/blob/master/SSToolkit/NSData+SSToolkitAdditions.m
- (NSString *)_calculateMD5Digest:(NSData *)data {
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
    CC_MD5(data.bytes, (unsigned int)data.length, digest);
    NSMutableString *ms = [NSMutableString string];
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ms appendFormat: @"%02x", (int)(digest[i])];
    }
    return [ms copy];
}

@end
