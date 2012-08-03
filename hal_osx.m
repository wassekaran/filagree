#import <Cocoa/Cocoa.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <OpenAL/al.h>
#include <OpenAL/alc.h>
#include <OpenGL/gl.h>
#include "struct.h"

static NSWindow *window;

void hal_loop() {
    [NSApp run];
}

void hal_window()
{
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    id menubar = [NSMenu new];
    id appMenuItem = [NSMenuItem new];
    [menubar addItem:appMenuItem];
    [NSApp setMainMenu:menubar];
    id appMenu = [NSMenu new];
    id appName = [[NSProcessInfo processInfo] processName];
    id quitTitle = [@"Quit " stringByAppendingString:appName];
    id quitMenuItem = [[NSMenuItem alloc] initWithTitle:quitTitle
                                                 action:@selector(terminate:)
                                          keyEquivalent:@"q"];
    [appMenu addItem:quitMenuItem];
    [appMenuItem setSubmenu:appMenu];
    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 200, 200)
                                         styleMask:NSTitledWindowMask |
                                                   NSClosableWindowMask |
                                                   NSMiniaturizableWindowMask |
                                                   NSResizableWindowMask
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
    [window cascadeTopLeftFromPoint:NSMakePoint(20,20)];
    [window setTitle:appName];
    [window makeKeyAndOrderFront:nil];
}

@interface GLView : NSOpenGLView

@end

@implementation GLView

- (id)initWithFrame:(NSRect)frameRect
{
    NSOpenGLPixelFormatAttribute attr[] = 
	{
        NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAAccelerated,
		NSOpenGLPFAColorSize, (NSOpenGLPixelFormatAttribute) 32,
		NSOpenGLPFADepthSize, (NSOpenGLPixelFormatAttribute) 23,
		(NSOpenGLPixelFormatAttribute) 0
	};
	NSOpenGLPixelFormat *nsglFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attr];
	
    if (self = [super initWithFrame:frameRect pixelFormat:nsglFormat]) {}
	return self;
}

- (void)prepareOpenGL
{
    glMatrixMode(GL_MODELVIEW);
	glClearColor(0, 0, .25, 0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glLoadIdentity();
    
	
    glShadeModel(GL_SMOOTH);
	glClearDepth(1.0f);
	glEnable(GL_DEPTH_TEST);
	glDepthFunc(GL_LEQUAL);
	glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
}

- (void)drawRect:(NSRect)rect
{
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
    glColor3f(1.0f, 0.85f, 0.35f);
    glBegin(GL_TRIANGLES);
    {
        glVertex3f(  0.0,  0.6, 0.0);
        glVertex3f( -0.2, -0.3, 0.0);
        glVertex3f(  0.2, -0.3 ,0.0);
    }
    glEnd();	
    [[self openGLContext] flushBuffer];
}


@end

void hal_graphics()
{
    NSView *content = [window contentView];
    NSRect rect = [content frame];
    rect.size.width /= 2;
    GLView *graph = [[GLView alloc] initWithFrame:rect];
    [graph drawRect:rect];
    [content addSubview:graph];
}

void hal_image()
{
    NSView *content = [window contentView];
    NSRect rect = [content frame];
    rect.origin.x = rect.size.width/2;
    NSImageView *iv = [[NSImageView alloc] initWithFrame:rect];

    NSURL *url = [NSURL URLWithString:@"http://www.cgl.uwaterloo.ca/~csk/projects/starpatterns/noneuclidean/323ball.jpg"];
    NSImage *pic = [[NSImage alloc] initWithContentsOfURL:url];
    if (pic)
        [iv setImage:pic];
    [content addSubview:iv];
}

void hal_sound()
{
    NSURL *url = [NSURL URLWithString:@"http://www.wavlist.com/soundfx/011/duck-quack3.wav"];
    NSSound *sound = [[NSSound alloc] initWithContentsOfURL:url byReference:FALSE];
    [sound play];
}

struct Sound {
    int seconds;
	size_t buf_size;
    short *samples;
    unsigned sample_rate;
};

#define CASE_RETURN(err) case (err): return "##err"
const char* al_err_str(ALenum err) {
    switch(err) {
            CASE_RETURN(AL_NO_ERROR);
            CASE_RETURN(AL_INVALID_NAME);
            CASE_RETURN(AL_INVALID_ENUM);
            CASE_RETURN(AL_INVALID_VALUE);
            CASE_RETURN(AL_INVALID_OPERATION);
            CASE_RETURN(AL_OUT_OF_MEMORY);
    }
    return "unknown";
}
#undef CASE_RETURN

#define __al_check_error(file,line) \
do { \
ALenum err = alGetError(); \
for(; err!=AL_NO_ERROR; err=alGetError()) { \
printf("AL Error %s at %s:%d\n", al_err_str(err), file, line ); \
} \
}while(0)

#define al_check_error() \
__al_check_error(__FILE__, __LINE__)

/* initialize OpenAL */
ALuint init_al() {
	ALCdevice *dev = NULL;
	ALCcontext *ctx = NULL;

	const char *defname = alcGetString(NULL, ALC_DEFAULT_DEVICE_SPECIFIER);
    printf("Default ouput device: %s\n", defname);

	dev = alcOpenDevice(defname);
	ctx = alcCreateContext(dev, NULL);
	alcMakeContextCurrent(ctx);

	/* Create buffer to store samples */
	ALuint buf;
	alGenBuffers(1, &buf);
	al_check_error();
    return buf;
}

/* Fill buffer with Sine-Wave */
struct Sound gen_sound() {
    float freq = 440.f;
	int seconds = 1;
	unsigned sample_rate = 22050;
	size_t buf_size = seconds * sample_rate;

	short *samples = malloc(sizeof(short) * buf_size);
	for(int i=0; i<buf_size; ++i)
		samples[i] = 32760 * sin( (2.f*M_PI*freq)/sample_rate * i );

    struct Sound sound = {seconds, buf_size, samples, sample_rate};
    return sound;
}

void play(ALuint buf, struct Sound *sound) {
    /* Download buffer to OpenAL */
	alBufferData(buf, AL_FORMAT_MONO16, sound->samples, sound->buf_size, sound->sample_rate);
	al_check_error();

	/* Set-up sound source and play buffer */
	ALuint src = 0;
	alGenSources(1, &src);
	alSourcei(src, AL_BUFFER, buf);
	alSourcePlay(src);

	/* While sound is playing, sleep */
	al_check_error();
	sleep(sound->seconds);
}

/* Dealloc OpenAL */
void exit_al() {
	ALCdevice *dev = NULL;
	ALCcontext *ctx = NULL;
	ctx = alcGetCurrentContext();
	dev = alcGetContextsDevice(ctx);

	alcMakeContextCurrent(NULL);
	alcDestroyContext(ctx);
	alcCloseDevice(dev);
}

void hal_synth()
{
    ALuint buf = init_al();
	struct Sound sound = gen_sound();
    play(buf, &sound);
	exit_al();
}

#define QUEUEBUFFERCOUNT 2
#define QUEUEBUFFERSIZE 9999

ALvoid hal_audio_loop(ALvoid)
{
    ALCdevice   *pCaptureDevice;
    const       ALCchar *szDefaultCaptureDevice;
    ALint       lSamplesAvailable;
    ALchar      Buffer[QUEUEBUFFERSIZE];
    ALuint      SourceID, TempBufferID;
    ALuint      BufferID[QUEUEBUFFERCOUNT];
    ALuint      ulBuffersAvailable = QUEUEBUFFERCOUNT;
    ALuint      ulUnqueueCount, ulQueueCount;
    ALint       lLoop, lFormat, lFrequency, lBlockAlignment, lProcessed, lPlaying;
    ALboolean   bPlaying = AL_FALSE;
    ALboolean   bPlay = AL_FALSE;

    // NOTE : This code does NOT setup the Wave Device's Audio Mixer to select a recording input or recording level.

	ALCdevice *dev = NULL;
	ALCcontext *ctx = NULL;
    
	const char *defname = alcGetString(NULL, ALC_DEFAULT_DEVICE_SPECIFIER);
    printf("Default ouput device: %s\n", defname);
    
	dev = alcOpenDevice(defname);
	ctx = alcCreateContext(dev, NULL);
	alcMakeContextCurrent(ctx);

    // Generate a Source and QUEUEBUFFERCOUNT Buffers for Queuing
    alGetError();
    alGenSources(1, &SourceID);

    for (lLoop = 0; lLoop < QUEUEBUFFERCOUNT; lLoop++)
        alGenBuffers(1, &BufferID[lLoop]);

    if (alGetError() != AL_NO_ERROR) {
        printf("Failed to generate Source and / or Buffers\n");
        return;
    }

    ulUnqueueCount = 0;
    ulQueueCount = 0;

    // Get list of available Capture Devices
    const ALchar *pDeviceList = alcGetString(NULL, ALC_CAPTURE_DEVICE_SPECIFIER);
    if (pDeviceList) {
        printf("Available Capture Devices are:-\n");

        while (*pDeviceList) {
            printf("%s\n", pDeviceList);
            pDeviceList += strlen(pDeviceList) + 1;
        }
    }

    szDefaultCaptureDevice = alcGetString(NULL, ALC_CAPTURE_DEFAULT_DEVICE_SPECIFIER);
    printf("\nDefault Capture Device is '%s'\n\n", szDefaultCaptureDevice);

    // The next call can fail if the WaveDevice does not support the requested format, so the application
    // should be prepared to try different formats in case of failure

    lFormat = AL_FORMAT_MONO16;
    lFrequency = 44100;
    lBlockAlignment = 2;

    long lTotalProcessed = 0;
    long lOldSamplesAvailable = 0;
    long lOldTotalProcessed = 0;

    pCaptureDevice = alcCaptureOpenDevice(szDefaultCaptureDevice, lFrequency, lFormat, lFrequency);
    if (pCaptureDevice) {
        printf("Opened '%s' Capture Device\n\n", alcGetString(pCaptureDevice, ALC_CAPTURE_DEVICE_SPECIFIER));

        printf("start capture\n");
        alcCaptureStart(pCaptureDevice);
        bPlay = AL_TRUE;

        for (;;) {
            //alcCaptureStop(pCaptureDevice);

            alGetError();
            alcGetIntegerv(pCaptureDevice, ALC_CAPTURE_SAMPLES, 1, &lSamplesAvailable);

            if ((lOldSamplesAvailable != lSamplesAvailable) || (lOldTotalProcessed != lTotalProcessed)) {
                printf("Samples available is %d, Buffers Processed %ld\n", lSamplesAvailable, lTotalProcessed);
                lOldSamplesAvailable = lSamplesAvailable;
                lOldTotalProcessed = lTotalProcessed;
            }

            // If the Source is (or should be) playing, get number of buffers processed
            // and check play status
            if (bPlaying) {
                alGetSourcei(SourceID, AL_BUFFERS_PROCESSED, &lProcessed);
                while (lProcessed) {
                    lTotalProcessed++;

                    // Unqueue the buffer
                    alSourceUnqueueBuffers(SourceID, 1, &TempBufferID);

                    // Update unqueue count
                    if (++ulUnqueueCount == QUEUEBUFFERCOUNT)
                        ulUnqueueCount = 0;

                    // Increment buffers available
                    ulBuffersAvailable++;

                    lProcessed--;
                }

                // If the Source has stopped (been starved of data) it will need to be
                // restarted
                alGetSourcei(SourceID, AL_SOURCE_STATE, &lPlaying);
                if (lPlaying == AL_STOPPED) {
                    printf("Buffer Stopped, Buffers Available is %d\n", ulBuffersAvailable);
                    bPlay = AL_TRUE;
                }
            }

            if ((lSamplesAvailable > (QUEUEBUFFERSIZE / lBlockAlignment)) && !(ulBuffersAvailable)) {
                printf("underrun!\n");
            }

            // When we have enough data to fill our QUEUEBUFFERSIZE byte buffer, grab the samples
            else if ((lSamplesAvailable > (QUEUEBUFFERSIZE / lBlockAlignment)) && (ulBuffersAvailable)) {
                // Consume Samples
                alcCaptureSamples(pCaptureDevice, Buffer, QUEUEBUFFERSIZE / lBlockAlignment);
                alBufferData(BufferID[ulQueueCount], lFormat, Buffer, QUEUEBUFFERSIZE, lFrequency);

                // Queue the buffer, and mark buffer as queued
                alSourceQueueBuffers(SourceID, 1, &BufferID[ulQueueCount]);
                if (++ulQueueCount == QUEUEBUFFERCOUNT)
                    ulQueueCount = 0;

                // Decrement buffers available
                ulBuffersAvailable--;

                // If we need to start the Source do it now IF AND ONLY IF we have queued at least 2 buffers
                if ((bPlay) && (ulBuffersAvailable <= (QUEUEBUFFERCOUNT - 2))) {
                    alSourcePlay(SourceID);
                    printf("Buffer Starting \n");
                    bPlaying = AL_TRUE;
                    bPlay = AL_FALSE;
                }
            }
        }
        alcCaptureCloseDevice(pCaptureDevice);
    } else
        printf("WaveDevice is unavailable, or does not supported the request format\n");

    alSourceStop(SourceID);
    alDeleteSources(1, &SourceID);
    for (lLoop = 0; lLoop < QUEUEBUFFERCOUNT; lLoop++)
    alDeleteBuffers(1, &BufferID[lLoop]);
}

void hal_label(int x, int y, int w, int h, const char *str) {
    NSView *content = [window contentView];
    NSRect rect = NSMakeRect(x, y, w, h);
    NSTextField *textField;    
    textField = [[NSTextField alloc] initWithFrame:rect];
    NSString *string = [NSString stringWithUTF8String:str];
    [textField setStringValue:string];
    [textField setBezeled:NO];
    [textField setDrawsBackground:NO];
    [textField setEditable:NO];
    [textField setSelectable:NO];
    [content addSubview:textField];
}

void hal_button(int x, int y, int w, int h, const char *str, const char *img1, const char* img2) {
    NSView *content = [window contentView];
    int frameHeight = [content frame].size.height;
    NSRect rect = NSMakeRect(x, frameHeight - y - h, w, h);

    NSButton *my = [[NSButton alloc] initWithFrame:rect];
    [content addSubview: my];
    NSString *string = [NSString stringWithUTF8String:str];
    [my setTitle:string];

    if (img1) {
        string = [NSString stringWithUTF8String:img1];
        NSURL* url = [NSURL fileURLWithPath:string];
        NSImage *image = [[NSImage alloc] initWithContentsOfURL: url];
        [my setImage:image] ;
    }

    //    [my setTarget:self];
    [my setAction:@selector(invisible)];
    [my setButtonType:NSMomentaryLightButton];
    [my setBezelStyle:NSTexturedSquareBezelStyle];
}

void hal_input(int x, int y, int w, int h, const char *str, BOOL multiline) {
    NSView *content = [window contentView];
    int frameHeight = [content frame].size.height;
    NSRect rect = NSMakeRect(x, frameHeight - y - h, w, h);
    NSString *string = [NSString stringWithUTF8String:str];

    NSView *textField;
    if (multiline)
        textField = [[NSTextView alloc] initWithFrame:rect];
    else
        textField = [[NSTextField alloc] initWithFrame:rect];
    [textField insertText:string];

    [content addSubview:textField];
}

@implementation NSArray (NSTableViewDataSource)

// just returns the item for the right row
- (id)     tableView:(NSTableView *) aTableView
objectValueForTableColumn:(NSTableColumn *) aTableColumn
                 row:(int) rowIndex
{  
    return [self objectAtIndex:rowIndex];  
}

// just returns the number of items we have.
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [self count];  
}

@end

void hal_table(int x, int y, int w, int h) {
    NSView *content = [window contentView];
    NSRect rect = NSMakeRect(x, y, w, h);
    NSScrollView * tableContainer = [[NSScrollView alloc] initWithFrame:rect];
    w -= 16;
    rect = NSMakeRect(x, y, w, h);
    NSTableView *tableView = [[NSTableView alloc] initWithFrame:rect];
    NSTableColumn * column1 = [[NSTableColumn alloc] initWithIdentifier:@"Col1"];
    [[column1 headerCell] setStringValue:@"yo"];

    [tableView addTableColumn:column1];
//  [tableView setDelegate:self];
    NSArray *source = [NSArray arrayWithObjects:@"3",@"1",@"4",nil];
    [tableView setDataSource:(id<NSTableViewDataSource>)source];
//  [tableView reloadData];
    [tableContainer setDocumentView:tableView];
    [tableContainer setHasVerticalScroller:YES];
    [content addSubview:tableContainer];
}

#if 0
int main(int argc, char *argv[])
{
    hal_window();
    hal_graphics();
    //hal_image();
//    hal_sound();
  //  hal_synth();
//    hal_button(0, 0, 100, 100, "hi", NULL);
//    hal_input(100, 100, 100, 100, "hi", NO);
    hal_table(20, 20, 100, 100);
//    hal_audio_loop();
    [NSApp run];
    return 0;
}
#endif