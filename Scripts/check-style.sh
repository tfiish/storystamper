#!/bin/bash
# Enforces the one rule DesignSystem.swift states: a view contains no raw
# design values. Geometry, color alpha, motion, stroke patterns, and named
# colors all come from a named token, so the interface has one place to change
# and no two controls drift apart by a point or a shade.
#
# Scope for the design-system rules is Sources/StoryStamper/Views.
# DesignSystem.swift is where the numbers live, and the renderer and exporter
# do arithmetic on pixels rather than drawing chrome, so neither is checked
# there. The two house rules at the end cover all of Sources.
#
# What is flagged:
#   1. A numeric literal inside a call the interface draws with—.frame,
#      .padding, .opacity, .shadow, StrokeStyle, and the rest of DRAWING_CALLS.
#   2. A numeric literal after a drawing argument label—lineWidth:, duration:,
#      dash:, and so on. This is what catches an argument sitting on its own
#      continuation line, which rule 1 cannot see: the check reads one line at
#      a time, because a Swift parser is not worth writing for this.
#   3. A named color hue—.orange, Color.green—which is a design value the
#      same way a number is. Palette holds the ones this app names; black
#      and white are exempt, being absolute rather than theme colors.
#   4. A CGFloat or Double constant declared in a view. Those are design
#      values by definition; declaring one locally is how the second copy of a
#      number starts.
#
# And across all of Sources, the two house rules DEVELOPING.md states but
# nothing used to check:
#   5. A force unwrap. Errors surface as readable messages, so there is no
#      case for crashing on a nil. Implicitly unwrapped optionals in a type
#      position are exempt: the ObjC bridge writes `Selector!` for us.
#   6. A debug write to stderr. One of these shipped in a release build, on
#      every appearance of a picker, carrying the only force unwrap in the
#      codebase—which is the whole argument for this rule costing a
#      millisecond. The smoke test is exempt: printing is its interface.
#
# The two sanctioned literals, and the only two:
#   spacing: 0            structural "no gap", not a value off the scale
#   opacity(flag ? 1 : 0) fully on or fully off, not an alpha
#
# Run it directly, or let ./Scripts/make-app.sh run it before a release build.
set -euo pipefail
cd "$(dirname "$0")/.."

ROOT="Sources/StoryStamper/Views"

if [ ! -d "$ROOT" ]; then
    echo "check-style: $ROOT not found" >&2
    exit 2
fi

perl -e '
use strict;
use warnings;

# Calls whose arguments end up on screen.
my @DRAWING_CALLS = qw(
    .padding .frame .offset .position .cornerRadius .shadow .blur
    .scaleEffect .strokeBorder .stroke .border .inset .system .animation
    .opacity .lineSpacing .kerning .seconds
    withAnimation StrokeStyle RoundedRectangle
);

# Argument labels that always name something drawn, wherever they appear.
my @DRAWING_LABELS = qw(
    lineWidth cornerRadius radius dash duration lineSpacing blurRadius every
);

my $LITERAL = qr/(?<![\w.])-?\d+(?:\.\d+)?/;
# Named hues, which belong in Palette. Black and white are deliberately absent.
my $HUES = qr/red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown|gr[ae]y/;
my $violations = 0;

my %reported;

# One line, one complaint. Several rules can catch the same literal, and three
# ways of saying "this line has a number in it" is not three problems.
sub report {
    my ($file, $number, $reason, $line) = @_;
    return if $reported{"$file:$number"}++;
    $line =~ s/^\s+//;
    print "$file:$number: $reason\n    $line\n";
    $violations++;
}

# The balanced argument text of a call, as far as this line goes. A call split
# across lines yields only what is on this one, which is what rule 2 is for.
sub arguments_at {
    my ($line, $open) = @_;
    my $depth = 0;
    my $args = "";
    for my $i ($open .. length($line) - 1) {
        my $char = substr($line, $i, 1);
        if ($char eq "(") {
            $depth++;
            next if $depth == 1;
        } elsif ($char eq ")") {
            $depth--;
            last if $depth == 0;
        }
        $args .= $char;
    }
    return $args;
}

for my $file (@ARGV) {
    open my $handle, "<", $file or die "check-style: cannot read $file: $!\n";
    my $number = 0;
    while (my $raw = <$handle>) {
        $number++;
        chomp $raw;
        my $line = $raw;

        # Comments and string contents are prose, not values.
        $line =~ s{"(?:\\.|[^"\\])*"}{""}g;
        $line =~ s{(?<!:)//.*$}{};

        # A named hue is a design value exactly like a number is, and it has
        # the same failure mode: the second opinion about which green means
        # "done" arrives as a literal in a view. Palette holds the ones this
        # app names; the system semantics (.primary, .secondary, .tint,
        # accentColor) need no permission.
        #
        # Black and white are exempt. Over video they are absolute colors
        # rather than theme ones—a scrim is black because it is darkening
        # pixels, not because the interface is in light mode.
        if ($line =~ /(?<![\w.])Color\.($HUES)(?![\w])/
            || $line =~ /(?:foregroundStyle|foregroundColor|fill|tint|stroke|strokeBorder)\(\s*\.($HUES)(?![\w])/) {
            report($file, $number, "named color .$1 in a view (use Palette)", $raw);
        }

        next unless $line =~ /\d/;

        for my $call (@DRAWING_CALLS) {
            my $at = 0;
            while ((my $found = index($line, "$call(", $at)) >= 0) {
                $at = $found + length($call) + 1;
                # A call name must not be the tail of a longer identifier.
                next if $call !~ /^\./ && $found > 0 && substr($line, $found - 1, 1) =~ /[\w.]/;
                my $args = arguments_at($line, $found + length($call));
                next unless $args =~ /$LITERAL/;
                # opacity(flag ? 1 : 0) is on or off, not an alpha value.
                next if $call eq ".opacity" && $args =~ /\?\s*1\s*:\s*0\s*$/;
                report($file, $number, "raw literal in $call(…)", $raw);
                last;
            }
        }

        for my $label (@DRAWING_LABELS) {
            next unless $line =~ /(?<![\w.])$label\s*:\s*($LITERAL)/;
            report($file, $number, "raw literal after $label:", $raw);
            last;
        }

        if ($line =~ /(?<![\w.])spacing\s*:\s*($LITERAL)/ && $1 ne "0") {
            report($file, $number, "raw literal after spacing: (only 0 is allowed)", $raw);
        }

        if ($line =~ /\b(?:let|var)\s+\w+\s*:\s*(CGFloat|Double)\s*=\s*$LITERAL/) {
            report($file, $number, "$1 constant declared in a view", $raw);
        }
    }
    close $handle;
}

if ($violations) {
    my $plural = $violations == 1 ? "line" : "lines";
    print "\ncheck-style: $violations $plural with raw design values. Add a named token to DesignSystem.swift and use it.\n";
    exit 1;
}
' $(find "$ROOT" -name "*.swift" | sort)

echo "check-style: no raw literals or named colors in $ROOT"

# The house rules, over everything. Cheap enough to be worth having: a debug
# write and a force unwrap reached a release build together once already.
perl -e '
use strict;
use warnings;

my $violations = 0;

for my $file (@ARGV) {
    open my $handle, "<", $file or die "check-style: cannot read $file: $!\n";
    # Printing is what the smoke test is for.
    my $prints = $file =~ /SmokeTest\.swift$/;
    my $number = 0;
    while (my $raw = <$handle>) {
        $number++;
        chomp $raw;
        my $line = $raw;
        $line =~ s{"(?:\\.|[^"\\])*"}{""}g;
        $line =~ s{(?<!:)//.*$}{};

        # An implicitly unwrapped optional in a type position is the ObjC
        # bridge talking, not a decision anyone made: `Selector!`, `NSWindow!`.
        my $code = $line;
        $code =~ s/:\s*[A-Z][\w.]*(?:<[^>]*>)?\s*!//g;

        if ($code =~ /[\w\)\]]!(?!=)/) {
            (my $trimmed = $raw) =~ s/^\s+//;
            print "$file:$number: force unwrap\n    $trimmed\n";
            $violations++;
        }

        next if $prints;
        if ($line =~ /FileHandle\.standardError|\bPROBE\b/) {
            (my $trimmed = $raw) =~ s/^\s+//;
            print "$file:$number: debug write to stderr\n    $trimmed\n";
            $violations++;
        }
    }
    close $handle;
}

if ($violations) {
    my $plural = $violations == 1 ? "line" : "lines";
    print "\ncheck-style: $violations $plural break a house rule. See DEVELOPING.md.\n";
    exit 1;
}
' $(find Sources -name "*.swift" | sort)

echo "check-style: no force unwraps or debug writes in Sources"
