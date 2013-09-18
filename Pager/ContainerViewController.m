//
//  ContainerViewController.m
//  Pager
//
//  Created by Alfie Hanssen on 9/17/13.
//  Copyright (c) 2013 Alfie Hanssen. All rights reserved.
//

#import "ContainerViewController.h"
#import "ContentViewController.h"

#define PARALLAX_SCALAR 0.5f
#define TRANSITION_DURATION 0.25f
#define PAN_COMPLETION_THRESHOLD 0.5f
#define VELOCITY_THRESHOLD 300.0f

typedef enum {
    PanDirectionBack,
    PanDirectionForward
} PanDirection;

@interface ContainerViewController ()
@property (nonatomic, assign) int index;
@property (nonatomic, strong) NSMutableArray * contentArray;
@property (nonatomic, strong) ContentViewController * currentViewController;
@property (nonatomic, strong) ContentViewController * nextViewController;
@end

@implementation ContainerViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.index = 0;
        self.loopingEnabled = NO;
        self.parallaxEnabled = YES;
        self.contentArray = [NSMutableArray arrayWithCapacity:5];
        [self.contentArray addObject:@"0000000"];
        [self.contentArray addObject:@"1111111"];
        [self.contentArray addObject:@"2222222"];
        [self.contentArray addObject:@"3333333"];
        [self.contentArray addObject:@"4444444"];
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIPanGestureRecognizer * pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    pan.delegate = self;
    pan.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:pan];

    UITapGestureRecognizer * tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self.view addGestureRecognizer:tap];
    
    self.currentViewController = [self viewControllerForIndex:self.index];
    self.currentViewController.view.frame = self.view.bounds;
    [self addChildViewController:self.currentViewController];
    [self.view addSubview:self.currentViewController.view];
    [self.currentViewController didMoveToParentViewController:self];
}

#pragma mark - UIGestureRecognizer Delegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    BOOL shouldBegin = YES;
    
    if (!self.loopingEnabled) {
        if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
            CGPoint translation = [(UIPanGestureRecognizer *)gestureRecognizer translationInView:self.view];
            PanDirection direction = (translation.x > 0) ? PanDirectionBack : PanDirectionForward;
            if (direction == PanDirectionBack && self.index == 0) {
                shouldBegin = NO;
            } else if (direction == PanDirectionForward && self.index == [self.contentArray count] -1) {
                shouldBegin = NO;
            }
        }
    }
    
    return shouldBegin;
}

#pragma mark - Gestures

- (void)tap:(UITapGestureRecognizer *)recognizer
{
    int index = (self.index + 2 >= [self.contentArray count]) ? [self.contentArray count] - 1 : self.index + 2;
    [self transitionToIndex:index];
}

- (void)pan:(UIPanGestureRecognizer *)recognizer
{
    CGPoint translation = [recognizer translationInView:self.view];
    PanDirection direction = (translation.x > 0) ? PanDirectionBack : PanDirectionForward;
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        self.nextViewController = [self viewControllerForDirection:direction]; // self.nextViewController is destroyed in the transition methods
        [self addChildViewController:self.nextViewController];
        [self.view addSubview:self.nextViewController.view];
    }
    
    ContentViewController * current = [self currentViewController]; //TODO: should currentViewController be an @property?
    float adjustedTranslation = (self.parallaxEnabled) ? translation.x * PARALLAX_SCALAR : translation.x;
    current.view.frame = (CGRect){adjustedTranslation, 0, current.view.frame.size};

    float originX = (direction == PanDirectionForward) ? self.view.frame.size.width : 0 - self.view.frame.size.width;
    self.nextViewController.view.frame = (CGRect){originX + translation.x, 0, self.nextViewController.view.frame.size};
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        if (ABS(translation.x) > self.view.frame.size.width * PAN_COMPLETION_THRESHOLD) {
            [self finishPanInDirection:direction withVelocity:[recognizer velocityInView:self.view] fromViewController:current toViewController:self.nextViewController];
        } else {
            [self cancelPanInDirection:direction fromViewController:current toViewController:self.nextViewController];
        }
    }
}

#pragma mark - Containment

- (void)transitionToIndex:(int)index
{
    ContentViewController * new = [self viewControllerForIndex:index];
    new.view.frame = self.view.bounds;
    
    [self addChildViewController:new];
    [self.currentViewController willMoveToParentViewController:nil];
    
    [self.view addSubview:new.view];
    [self.currentViewController.view removeFromSuperview];
    
    [new didMoveToParentViewController:self];
    [self.currentViewController removeFromParentViewController];
    
    self.currentViewController = new;
    
    self.index = index;
}

- (void)finishPanInDirection:(PanDirection)direction withVelocity:(CGPoint)velocity fromViewController:(UIViewController *)old toViewController:(UIViewController *)new
{
    if (old && new) {
        
        [old willMoveToParentViewController:nil];
        
        CGRect oldFrame = CGRectZero;
        if (direction == PanDirectionForward) {
            self.index = [self nextIndex];
            oldFrame = [self previousFrame:YES];
        } else {
            self.index = [self previousIndex];
            oldFrame = [self nextFrame:YES];
        }
        
        float duration = TRANSITION_DURATION;
        if (ABS(velocity.x) > VELOCITY_THRESHOLD) {
            duration = TRANSITION_DURATION * (ABS(new.view.frame.origin.x) / new.view.frame.size.width);
        }
        
        __weak ContainerViewController * weakSelf = self;
        [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            
            old.view.frame = oldFrame;
            new.view.frame = weakSelf.view.bounds;
            
        } completion:^(BOOL finished) {
            [old.view removeFromSuperview];
            [old removeFromParentViewController];
            [new didMoveToParentViewController:weakSelf];
            weakSelf.currentViewController = weakSelf.nextViewController;
            weakSelf.nextViewController = nil;
        }];
    }
}

- (void)cancelPanInDirection:(PanDirection)direction fromViewController:(UIViewController *)old toViewController:(UIViewController *)new
{
    if (old && new) {
        
        CGRect newFrame = CGRectZero;
        if (direction == PanDirectionForward) {
            newFrame = [self nextFrame:NO];
        } else {
            newFrame = [self previousFrame:NO];
        }
        
        __weak ContainerViewController * weakSelf = self;
        [UIView animateWithDuration:TRANSITION_DURATION delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            
            new.view.frame = newFrame;
            old.view.frame = weakSelf.view.bounds;
            
        } completion:^(BOOL finished) {
            [new.view removeFromSuperview];
            [new removeFromParentViewController];
            weakSelf.nextViewController = nil;
        }];
    }
}

- (ContentViewController *)viewControllerForDirection:(PanDirection)direction
{
    int index = 0;
    CGRect frame = CGRectZero;
    if (direction == PanDirectionForward) {
        index = [self nextIndex];
        frame = [self nextFrame:NO];
    } else {
        index = [self previousIndex];
        frame = [self previousFrame:NO];
    }
    
    ContentViewController * vc = [self viewControllerForIndex:index];
    vc.view.frame = frame;
    return vc;
}

- (ContentViewController *)viewControllerForIndex:(int)index
{
    NSString * content = [self.contentArray objectAtIndex:index];
    ContentViewController * new = [[ContentViewController alloc] initWithContent:content];
    return new;
}

//- (ContentViewController *)currentViewController
//{
//    ContentViewController * vc = nil;
//    if ([self.childViewControllers count]) {
//        vc = [self.childViewControllers objectAtIndex:0];
//    }
//    return vc;
//}

#pragma mark - Indexing

- (int)nextIndex
{
    int index = 0;
    if (self.loopingEnabled) {
        index = (self.index + 1 >= [self.contentArray count]) ? 0 : self.index + 1;
    } else {
        index = MIN(self.index + 1, [self.contentArray count] - 1);
    }
    return index;
}

- (int)previousIndex
{
    int index = 0;
    if (self.loopingEnabled) {
        index = (self.index - 1 < 0) ? [self.contentArray count] - 1 : self.index - 1;
    } else {
        index = MAX(0, self.index - 1);
    }
    return index;
}

#pragma mark - Frames

- (CGRect)nextFrame:(BOOL)obeyParallax
{
    CGRect rect = CGRectZero;
    if (self.parallaxEnabled && obeyParallax) {
        rect = (CGRect){self.view.bounds.size.width * PARALLAX_SCALAR, 0, self.view.bounds.size};
    } else {
        rect = (CGRect){self.view.bounds.size.width, 0, self.view.bounds.size};
    }
    return rect;
}

- (CGRect)previousFrame:(BOOL)obeyParallax
{
    CGRect rect = CGRectZero;
    if (self.parallaxEnabled && obeyParallax) {
        rect = (CGRect){0 - self.view.bounds.size.width * PARALLAX_SCALAR, 0, self.view.bounds.size};
    } else {
        rect = (CGRect){0 - self.view.bounds.size.width, 0, self.view.bounds.size};;
    }
    return rect;
}

@end
