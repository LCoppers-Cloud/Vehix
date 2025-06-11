#ifndef ItemSelectionRow_h
#define ItemSelectionRow_h

#import <SwiftUI/SwiftUI.h>

@interface ItemSelectionRow : View
- (instancetype)initWithTitle:(NSString *)title 
                    subtitle:(NSString *)subtitle 
                  isSelected:(BOOL)isSelected 
                      onTap:(void (^)(void))onTap;
@end

#endif /* ItemSelectionRow_h */ 