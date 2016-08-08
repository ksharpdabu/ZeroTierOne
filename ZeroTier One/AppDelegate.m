//
//  AppDelegate.m
//  ZeroTier One
//
//  Created by Grant Limberg on 8/7/16.
//  Copyright © 2016 ZeroTier, Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "NetworkMonitor.h"
#import "Network.h"
#import "NodeStatus.h"
#import "JoinNetworkViewController.h"
#import "ShowNetworksViewController.h"
#import "PreferencesViewController.h"
#import "AboutViewController.h"
#import "ServiceCom.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:-2.0f];
    self.networkListPopover = [[NSPopover alloc] init];
    self.joinNetworkPopover = [[NSPopover alloc] init];
    self.preferencesPopover = [[NSPopover alloc] init];
    self.aboutPopover = [[NSPopover alloc] init];
    self.transientMonitor = nil;
    self.monitor = [[NetworkMonitor alloc] init];
    self.networks = [NSMutableArray<Network*> array];
    self.status = nil;
    self.pasteboard = [NSPasteboard generalPasteboard];

    [self.pasteboard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *defaultsDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"firstRun"];
    [defaults registerDefaults:defaultsDict];

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self
           selector:@selector(onNetworkListUpdated:)
               name:NetworkUpdateKey
             object:nil];
    [nc addObserver:self
           selector:@selector(onNodeStatusUpdated:)
               name:StatusUpdateKey
             object:nil];

    self.statusItem.image = [NSImage imageNamed:@"MenuBarIconMac"];

    [self buildMenu];

    self.joinNetworkPopover.contentViewController = [[JoinNetworkViewController alloc] initWithNibName:@"JoinNetworkViewController" bundle:nil];
    self.joinNetworkPopover.behavior = NSPopoverBehaviorTransient;

    ShowNetworksViewController *showNetworksView = [[ShowNetworksViewController alloc] initWithNibName:@"ShowNetworksViewController" bundle:nil];
    showNetworksView.netMonitor = self.monitor;
    self.networkListPopover.contentViewController = showNetworksView;
    self.networkListPopover.behavior = NSPopoverBehaviorTransient;

    PreferencesViewController *prefsView = [[PreferencesViewController alloc] initWithNibName:@"PreferencesViewController" bundle:nil];
    self.preferencesPopover.contentViewController = prefsView;
    self.preferencesPopover.behavior = NSPopoverBehaviorTransient;

    self.aboutPopover.contentViewController = [[AboutViewController alloc] initWithNibName:@"AboutViewController" bundle:nil];
    self.aboutPopover.behavior = NSPopoverBehaviorTransient;

    BOOL firstRun = [defaults boolForKey:@"firstRun"];

    if(firstRun) {
        [defaults setBool:NO forKey:@"firstRun"];
        [defaults synchronize];

        [prefsView setLaunchAtLoginEnabled:YES];

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self showAbout];
        }];
    }

    [self.monitor updateNetworkInfo];
    [self.monitor start];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showNetworks {
    if(self.statusItem.button != nil) {
        NSStatusBarButton *button = self.statusItem.button;
        [self.networkListPopover showRelativeToRect:button.bounds
                                             ofView:button
                                      preferredEdge:NSMinYEdge];

        if(self.transientMonitor == nil) {
            self.transientMonitor =
            [NSEvent addGlobalMonitorForEventsMatchingMask:(NSLeftMouseDown|NSRightMouseDown|NSOtherMouseDown)
                                                   handler:^(NSEvent * _Nonnull e) {
                                                       [NSEvent removeMonitor:self.transientMonitor];
                                                       self.transientMonitor = nil;
                                                       [self.networkListPopover close];
                                                   }];
        }
    }
}

- (void)joinNetwork {
    if(self.statusItem.button != nil) {
        NSStatusBarButton *button = self.statusItem.button;
        [self.joinNetworkPopover showRelativeToRect:button.bounds
                                             ofView:button
                                      preferredEdge:NSMinYEdge];
        if(self.transientMonitor == nil) {
            self.transientMonitor =
            [NSEvent addGlobalMonitorForEventsMatchingMask:(NSLeftMouseDown|NSRightMouseDown|NSOtherMouseDown)
                                                   handler:^(NSEvent * _Nonnull e) {
                                                       [NSEvent removeMonitor:self.transientMonitor];
                                                       self.transientMonitor = nil;
                                                       [self.joinNetworkPopover close];
                                                   }];
        }
    }
}

- (void)showPreferences {
    if(self.statusItem.button != nil) {
        NSStatusBarButton *button = self.statusItem.button;
        [self.preferencesPopover showRelativeToRect:button.bounds
                                             ofView:button
                                      preferredEdge:NSMinYEdge];
        if(self.transientMonitor == nil) {
            [NSEvent addGlobalMonitorForEventsMatchingMask:(NSLeftMouseDown|NSRightMouseDown|NSOtherMouseDown)
                                                   handler:^(NSEvent * _Nonnull e) {
                                                       [NSEvent removeMonitor:self.transientMonitor];
                                                       self.transientMonitor = nil;
                                                       [self.preferencesPopover close];
                                                   }];
        }
    }
}

- (void)showAbout {
    if(self.statusItem.button != nil) {
        NSStatusBarButton *button = self.statusItem.button;
        [self.aboutPopover showRelativeToRect:button.bounds
                                       ofView:button
                                preferredEdge:NSMinYEdge];
        if(self.transientMonitor == nil) {
            [NSEvent addGlobalMonitorForEventsMatchingMask:(NSLeftMouseDown|NSRightMouseDown|NSOtherMouseDown)
                                                   handler:^(NSEvent * _Nonnull e) {
                                                       [NSEvent removeMonitor:self.transientMonitor];
                                                       self.transientMonitor = nil;
                                                       [self.aboutPopover close];
                                                   }];
        }
    }

}

- (void)quit {
    [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
}

- (void)onNetworkListUpdated:(NSNotification*)note {
    NSArray<Network*> *netList = [note.userInfo objectForKey:@"networks"];
    [(ShowNetworksViewController*)self.networkListPopover.contentViewController setNetworks:netList];
    self.networks = [netList mutableCopy];

    [self buildMenu];
}

- (void)onNodeStatusUpdated:(NSNotification*)note {
    NodeStatus *status = [note.userInfo objectForKey:@"status"];
    self.status = status;

    [self buildMenu];
}

- (void)buildMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self;

    if(self.status != nil) {
        NSString *nodeId = @"Node ID: ";
        nodeId = [nodeId stringByAppendingString:self.status.address];
        [menu addItem:[[NSMenuItem alloc] initWithTitle:nodeId
                                                 action:@selector(copyNodeID)
                                          keyEquivalent:@""]];
        [menu addItem:[NSMenuItem separatorItem]];
    }

    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Network Details..."
                                             action:@selector(showNetworks)
                                      keyEquivalent:@"n"]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Join Network..."
                                             action:@selector(joinNetwork)
                                      keyEquivalent:@"j"]];

    [menu addItem:[NSMenuItem separatorItem]];

    if([self.networks count] > 0) {
        for(Network *net in self.networks) {
            NSString *nwid = [NSString stringWithFormat:@"%10llx", net.nwid];
            NSString *networkName = @"";
            if([net.name lengthOfBytesUsingEncoding:NSUTF8StringEncoding] == 0) {
                networkName = nwid;
            }
            else {
                networkName = [NSString stringWithFormat:@"%@ (%@)", nwid, net.name];
            }

            if(net.allowDefault && net.connected) {
                networkName = [networkName stringByAppendingString:@" [default]"];
            }

            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:networkName
                                                          action:@selector(toggleNetwork:)
                                                   keyEquivalent:@""];
            if(net.connected) {
                item.state = NSOnState;
            }
            else {
                item.state = NSOffState;
            }

            item.representedObject = net;

            [menu addItem:item];
        }

        [menu addItem:[NSMenuItem separatorItem]];
    }

    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"About ZeroTier One..."
                                             action:@selector(showAbout)
                                      keyEquivalent:@""]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Preferences..."
                                             action:@selector(showPreferences)
                                      keyEquivalent:@""]];

    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit"
                                             action:@selector(quit)
                                      keyEquivalent:@"q"]];

    self.statusItem.menu = menu;
}

- (void)toggleNetwork:(NSMenuItem*)sender {
    Network *network = sender.representedObject;
    NSString *nwid = [NSString stringWithFormat:@"%10llx", network.nwid];

    if(network.connected) {
        [[ServiceCom sharedInstance] leaveNetwork:nwid];
    }
    else {
        [[ServiceCom sharedInstance] joinNetwork:nwid
                                    allowManaged:network.allowManaged
                                     allowGlobal:network.allowGlobal
                                    allowDefault:(network.allowDefault && ![Network defaultRouteExists:self.networks])];
    }
}

- (void)copyNodeID {
    if(self.status != nil) {
        [self.pasteboard setString:self.status.address forType:NSPasteboardTypeString];
    }
}

- (void)menuWillOpen:(NSMenu*)menu {

}

- (void)menuDidClose:(NSMenu*)menu {

}

@end
