//
//  TransparentWidgetBackground.m
//  Widget-ios
//
//  WidgetKit has no public way to opt out of the system's background tile:
//  `containerBackground(.clear, for: .widget)` still sits on a white or dark
//  platter. Whether a widget gets that platter is decided by flags on the
//  widget descriptors the extension sends to the system over XPC. This file
//  intercepts that reply and gives every Chronograph descriptor the glass
//  style, so widgets sit on a blurred tile of the wallpaper and paint a solid
//  background only when the user sets a background color.
//
//  All of this is private API, looked up by name at runtime. When a name is
//  missing, as it may be on a future iOS, nothing is hooked or changed and the
//  widgets keep the standard platter.
//

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const ChronographExportedObjectClass =
    @"_TtCC9WidgetKit24WidgetExtensionXPCServer14ExportedObject";
static NSString *const ChronographDescriptorFetchSelector = @"getAllCurrentDescriptorsWithCompletion:";
static NSString *const ChronographWidgetDescriptorClass = @"CHSWidgetDescriptor";

/// Calls a private BOOL setter, if the object has it.
static void ChronographSetBool(id object, NSString *setterName, BOOL value) {
  SEL setter = NSSelectorFromString(setterName);
  if (![object respondsToSelector:setter]) return;
  ((void (*)(id, SEL, BOOL))objc_msgSend)(object, setter, value);
}

/// Calls a private integer setter, if the object has it.
static void ChronographSetInteger(id object, NSString *setterName, NSUInteger value) {
  SEL setter = NSSelectorFromString(setterName);
  if (![object respondsToSelector:setter]) return;
  ((void (*)(id, SEL, NSUInteger))objc_msgSend)(object, setter, value);
}

/// Replaces each widget descriptor with a transparent copy while the fetch
/// result is decoded, so the rebuilt result carries the new flags.
@interface ChronographTransparentDescriptors : NSObject <NSKeyedUnarchiverDelegate>
@end

@implementation ChronographTransparentDescriptors

- (id)unarchiver:(NSKeyedUnarchiver *)unarchiver didDecodeObject:(id)object {
  Class descriptorClass = NSClassFromString(ChronographWidgetDescriptorClass);
  if (descriptorClass == Nil || ![object isKindOfClass:descriptorClass]) return object;
  if (![object respondsToSelector:@selector(mutableCopyWithZone:)]) return object;

  id descriptor = [object mutableCopy];
  ChronographSetBool(descriptor, @"setTransparent:", YES);
  ChronographSetBool(descriptor, @"setBackgroundRemovable:", YES);
  // Lets the system tint text for legibility against the blur.
  ChronographSetBool(descriptor, @"setSupportsVibrantContent:", YES);
  // 2 is the glass style, a blurred wallpaper tile; 1 would draw no tile.
  ChronographSetInteger(descriptor, @"setPreferredBackgroundStyle:", 2);
  return descriptor;
}

@end

/// Round-trips the fetch result through a keyed archive, swapping descriptors
/// on the way back in. Any failure returns the original result unchanged.
static id ChronographTransparentFetchResult(id result) {
  if (result == nil) return result;

  NSError *error = nil;
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:result requiringSecureCoding:YES error:&error];
  if (data == nil) return result;

  NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
  if (unarchiver == nil) return result;

  ChronographTransparentDescriptors *substitutor = [ChronographTransparentDescriptors new];
  unarchiver.delegate = substitutor;
  id rebuilt = [unarchiver decodeObjectOfClass:[result class] forKey:NSKeyedArchiveRootObjectKey];
  [unarchiver finishDecoding];
  return rebuilt ?: result;
}

@interface ChronographTransparentWidgetBackground : NSObject
@end

@implementation ChronographTransparentWidgetBackground

+ (void)load {
  Class exportedObject = NSClassFromString(ChronographExportedObjectClass);
  if (exportedObject == Nil) return;

  SEL selector = NSSelectorFromString(ChronographDescriptorFetchSelector);
  Method method = class_getInstanceMethod(exportedObject, selector);
  if (method == NULL) return;

  typedef void (*FetchDescriptors)(id, SEL, void (^)(id));
  FetchDescriptors original = (FetchDescriptors)method_getImplementation(method);

  IMP replacement = imp_implementationWithBlock(^(id server, void (^completion)(id)) {
    original(server, selector, ^(id result) {
      completion(ChronographTransparentFetchResult(result));
    });
  });
  method_setImplementation(method, replacement);
}

@end
