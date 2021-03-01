package HTML::Spacing::JA;

use 5.008001;
use strict;
use warnings;
use feature 'say';

our $VERSION = "0.01";

=encoding ja.UTF-8

=head1 NAME

HTML::Spacing::JA - arrange spacing in ja text

=cut

use base qw(Class::Accessor);

__PACKAGE__->mk_accessors(qw( output_tag lang_spacing number_spacing
                              punct_spacing uri_ascii re_token re_pre
                              re_code emspace enspace wordspace
                              thinspace palt0 palt1 keep_global
                              verbose ));

use utf8;
use HTML::TreeBuilder;
use HTML::Element;
use HTML::Entities;
use Exporter 'import';
our @EXPORT_OK = qw($PUA_free %PUA %TOKEN %CLASS);

=head1 SYNOPSIS

 use HTML::Spacing::JA;
 $ja = HTML::Spacing::JA->new();
 $output = $ja->parse($input);

=cut

our $PUA_free = 1000000;        # 0xF4240
our %PUA;
our %TOKEN;
our %CLASS;

sub _cc {
  join '', map keys %{$CLASS{$_}}, @_;
}

sub InPUA  { "F0000\tFFFFF" }

sub _pua {
  pack "U", $PUA_free++;
}

my ($_emspace, $_enspace, $_wordspace, $_thinspace);
sub _emspace   { $_emspace   //= _pua() }
sub _enspace   { $_enspace   //= _pua() }
sub _wordspace { $_wordspace //= _pua() }
sub _thinspace { $_thinspace //= _pua() }

sub parse {
  my ($self, $text) = @_;
  if ($self->keep_global) {
    $self->_parse($text);
  } else {
    local $PUA_free = $PUA_free;
    local %PUA = %PUA;
    local %TOKEN = %TOKEN;
    local %CLASS = %CLASS;
    $self->_parse($text);
  }
}

sub _parse {
  my ($self, $text) = @_;

  my $html;
  if (!ref $text) {
    ($html) = grep { ref && $_->tag eq 'body' }
      HTML::TreeBuilder->new_from_content($text)->content_list;
    die "cant parse \$text\n" unless ref $html;
  } elsif (ref $text eq 'HTML::Element') {
    $html = $text;
  } else {
    die "can't parse ", ref $text, "\n";
  }

  join '', map { ref ? $_->as_HTML : $_ } $self->arrange($html)->content_list;

=begin comment

  s{ ( \&(?:\#(?:x(F[0-9A-F]{4})
         |(1\d{6}|99\d{4}|98[4-9]\d{3}|983[1-9]\d{2}|9830[4-9]\d))
       | [^;]+ );
     )
   | (\p{InPUA})}{
     my $c = $4 ? $4 : $2 ? chr(hex($2)) : $3 ? chr($3) : decode_entities($1);
     my $e = $PUA{$c} // $&;
     #ref $e ? $e->as_HTML : encode_entities($e);
     ref $e ? $e->as_HTML : $e;
   }gex;

=end comment

=cut

}


our $FORMATTED = 0;
our $TEXT = '';

sub arrange {
  my ($self, $html) = @_;

  local $FORMATTED = 0;
  local $TEXT = '';

  $self->arrange_spacing($html);
  $self->reduce_spacing($html);

  $self->restore_token($html);

  if (my $tag_attr = $self->output_tag) {
    my ($tag, @attr) = ref $tag_attr ? @$tag_attr : $tag_attr;
    my $output = HTML::Element->new($tag, @attr);
    if ($self->punct_spacing) {
      $self->attr($output, %$_) for grep defined && ref, $self->palt1;
    }
    $output->push_content($html->detach_content);
    $html->push_content($output);
  }

  $html;
}


sub arrange_spacing {
  my ($self, $parent) = @_;

  my $re_pre  = $self->re_pre;
  my $re_code = $self->re_code;

  for (my $pindex = 0; $pindex < scalar $parent->content_list; $pindex++) {
    for ($parent->content->[$pindex]) {

      if (ref) {

        if ($re_pre && $_->tag =~ /$re_pre/) {
          ;
        } elsif ($re_code && $_->tag =~ /$re_code/) {

          $FORMATTED++;
          $self->arrange_spacing($_);
          --$FORMATTED;

        } else {

          if ($self->uri_ascii) {
            if ($_->tag eq 'a') {
              if ($_->attr('href') && $_->attr('href') eq $_->as_text) {
                if ($self->uri_ascii) {
                  my ($uri, $chunk) = $_->as_text =~ m{^([[:ascii:]]+)(.*)};
                  if ($chunk) {
                    $_->attr('href', $uri);
                    $_->detach_content();
                    $_->push_content($uri);
                    $_->postinsert(_wordspace() . $chunk);
                  }
                }
              }
            }
          }

          $self->arrange_spacing($_);
        }

      } else {

        my $plan_b;
        my ($j, $n, $w);

        if ($FORMATTED) {
          $plan_b = 0;

          if (/^(\p{InSpaces}*)(.*?)(\p{InSpaces}*)$/) {
            my ($a, $b, $c) = ($1 // '', $2 // '', $3 // '');
            $_ = $a . $self->_token($b, 'W') . $c;
          }

        } else {
          $plan_b = 1;

          if (my $re = $self->re_token) {
            if (ref $re eq 'HASH') {
              for my $c (keys %{$re}) {
                if (my $re_c = $re->{$c}) {
                  s{$re_c}{$self->_token($&, $c)}eg;
                }
              }
            }
          }

          s{\p{InWestern}+(?:\p{InSpaces}+\p{InWestern}+)*}{$self->token($&)}eg;
        }

        $j  = _cc('J');
        $n  = _cc('N');
        $w  = _cc('W');
        $j  = $j  ? qr/[$j\p{InJapanese}]/ : qr/\p{InJapanese}/;
        $n  = $n  ? qr/[$n\p{InNumbers}]/  : qr/\p{InNumbers}/;
        $w  = $w  ? qr/[$w\p{InWestern}]/  : qr/\p{InWestern}/;

        if (!$FORMATTED) {

          # ignore line breaks in japanese.
          1 while s/($j)\s+($j)/$1$2/g;

          if ($self->lang_spacing) {
            s/($j)($w)/$1._wordspace().$2/eg;
            s/($w)($j)/$1._wordspace().$2/eg;
          }

          if ($self->number_spacing) {
            s/($j)($n)/$1._thinspace().$2/eg;
            s/($n)($j)/$1._thinspace().$2/eg;
          }

          if ($self->punct_spacing) {
            # 3.1.2
            s/(\p{InStartingJ})/_enspace().$1/eg;
            s/(\p{InEndingJ})/$1._enspace()/eg;
            s/(\p{InMiddleDotsJ}+)/_wordspace().$1._wordspace()/eg;

            # add wordspace when Western punctuation marks are used in
            # Japanese sentences.
            s/(\p{InJapanese})(\p{InStartingW})/$1._wordspace().$2/eg;
            s/(\p{InEndingW})(\p{InJapanese})/$1._wordspace().$2/eg;

            s{\p{InSpaces}{2,}}{$self->preferred_space($&) // " "}ge;

            # remove the wordspace (mechanically inserted) between the
            # manpage name and its (section).
            s/($w)\p{IsWordSpace}(\p{InStartingW})/$1$2/g;

            # 3.1.4
            s/\p{InSpaces}+(\p{InEnding})/$1/g;
            s/(\p{InStarting})\p{InSpaces}+/$1/g;

          }

          s/\p{InSpace2}+(\p{InNeutral})/$1/g;
          s/(\p{InNeutral})\p{InSpace2}+/$1/g;

        }

        # arrange spacing from the previous element.
        my $leading = '';
        $leading .= $&
          if $TEXT =~ s/\p{InSpaces}+$//;
        $leading .= $&
          if /\P{InSpaces}/ && s/^\p{InSpaces}+//;

        $leading = ''
          if $TEXT =~ /$j$/ && /^$j/;

        if ($self->lang_spacing) {
          $leading .= _wordspace()
            if $TEXT =~ /$j$/ && /^$w/
            || $TEXT =~ /$w$/ && /^$j/;
        }

        if ($self->number_spacing) {
          $leading .= _thinspace()
            if $TEXT =~ /$j$/ && /^$n/
            || $TEXT =~ /$n$/ && /^$j/;
        }

        if ($self->punct_spacing) {
          $leading = ''
            if $TEXT =~ /\p{InStarting}$/ || /^\p{InEnding}/;

          $leading = $self->preferred_space($leading) // '';
        }

        if ($leading) {
          unless ($self->add_space($parent, $pindex - 1, $leading)) {
            $_ = $leading . $_ if $plan_b;
          }
        }

        $TEXT = $_;
        /\P{InSpaces}/ && s/\p{InSpaces}+$//;
        $parent->splice_content($pindex, 1, $_);

      }

    }
  }
}


sub preferred_space {
  my ($self, $spaces) = @_;
  for ($spaces) {
    if (defined && /\p{InSpaces}/) {
      # 入力されたスペースがあればそれを返す。
      return $& if /\s/;
      # 適切なスペースを返す。大きなものを選ぶ。
      return $& if /\p{IsEmSpace}/;
      return $& if /\p{IsEnSpace}/;
      return $& if /\p{IsWordSpace}/;
      return $& if /\p{IsThinSpace}/;
    }
  }
  undef;
}


sub add_space {
  my ($self, $parent, $pindex, $text) = @_;

  if ($text =~ /\P{InSpaces}/) {
    die "# can't happen: \$text matches /\\p{InSpaces}/";
  }

  if ($pindex < 0) {
    return 0 unless $parent->parent;
    return $self->add_space($parent->parent, $parent->pindex - 1, $text);
  } elsif ($pindex < scalar $parent->content_list) {
    if (ref $parent->content->[$pindex]) {
      return 0;
    } else {
      $parent->content->[$pindex] .= $text;
      return 1;
    }
  } else {
    die "# can't happen: \$pindex is out of range";
  }
}


sub reduce_spacing {
  my ($self, $parent) = @_;

  my @chunk = ();
  for ($parent->detach_content) {
    if (ref) {
      push @chunk, $self->reduce_spacing($_);
    } else {

      if ($self->punct_spacing > 0) {
        my @list = split /\p{InSpaces}(\p{InMiddleDotsJ})\p{InSpaces}
                        | \p{InSpaces}(\p{InStartingJ})
                        | (\p{InEndingJ})\p{InSpaces}
                         /x;
        while (@list) {
          my ($chunk, $md, $ps, $pe) = splice @list, 0, 1 + 3;
          push @chunk, grep defined, $chunk;
          if (my $c = $md // $ps // $pe) {
            my $e = HTML::Element->new('span');
            $self->attr($e, %$_) for grep defined && ref, $self->palt0;
            $e->push_content($c);
            push @chunk, $e;
          }
        }
      } else {
        push @chunk, $_;
      }
    }
  }
  $parent->push_content(@chunk);
  $parent;
}


sub token {
  my ($self, $chunk, $class) = @_;

  for ($chunk) {

    return '' if !defined || /^$/;
    return $_ if /[^\p{InWestern}\p{InSpaces}]/;
    return $_ if /^[\p{InPunctuations}\p{InSpaces}]+$/;

    if (/^(\p{InNumbers}+)(.*)$/) {
      my ($a, $b) = ($1, $2 // '');
      if ($a =~ /\d/ && (!$b || $b !~ /^\p{InWestern}/)) {
        return $self->_token($a, $class // 'N') . $self->token($b, $class);
      }
    }

    # 複雑なものは分けて
    if (/(.*?\p{Ps})(.*?)(\p{Pe}.*)/) {
      my ($a, $b, $c) = ($1, $2 // '', $3);
      return $self->token($a, $class // 'W') . $self->token($b, $class // 'W') .
        $self->token($c, $class // 'W');
    }

    my ($pretoken, $posttoken) = ('', '');

    # はじめと終わりの記号類を取り除く。
    $pretoken  = $& if s/^[\p{InPunctuations}\p{InSpaces}]+//;
    $posttoken = $& if s/[\p{InPunctuations}\p{InSpaces}]+$//;

    return $pretoken . $self->_token($_, 'W') . $posttoken;
  }
}


sub _token {
  my ($self, $token, $class) = @_;
  $token //= '';
  unless ($token && defined $TOKEN{$token}) {
    my $pua = $TOKEN{$token} = _pua();
    say STDERR "# token: '$token', ", sprintf "\\x{%X}", ord($pua) if $self->verbose >= 2;
    if ($self->verbose) {
      my $color = $class eq 'N' ? '#f88' : '#888';
      my $elem = HTML::Element->new('span', style => "border: thin dotted $color");
      $elem->push_content($token);
      $PUA{$pua} = $elem;
    } else {
      $PUA{$pua} = $token;
    }
    $CLASS{$class}{$pua}++ if $class;
  }
  $TOKEN{$token};
}


sub restore_token {
  my ($self, $parent) = @_;
  my @chunk;
  for ($parent->detach_content) {
    if (ref) {
      $parent->push_content($self->restore_token($_));
    } else {
      my @list = split /(\p{InPUA})/;
      while (@list) {
        my ($chunk, $pua) = splice @list, 0, 2;
        $parent->push_content($chunk) if defined $chunk;
        if ($pua) {
          my $elem = $PUA{$pua} // $pua;
          $parent->push_content(ref $elem ? $elem->clone : $elem);
        }
      }
    }
  }
  $parent->push_content(@chunk);
  $parent;
}


sub attr {
  my ($self, $elem, %args) = @_;
  while (my ($key, $value) = each %args) {
    if (ref $value) {
      my %x;
      if (my $tmp = $elem->attr($key)) {
        $x{$1} = $2 while $tmp =~ /([\w\-]+):\s*([^;]*);?/g;
      }
      my @delete;
      while (my ($key, $value) = each %{$value}) {
        if (defined $value) {
          $x{$key} = $value;
        } else {
          push @delete, $key;
        }
      }
      delete @x{@delete};
      $value = join '; ', map "$_: $x{$_}", keys %x;
      $elem->attr($key, $value || undef);
    } else {
      $elem->attr($key, $value);
    }
  }
}


sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = bless { @_ }, $class;
  $self->init();
  $self;
}


sub init {
  my $self = shift;

  my %default = (
    output_tag => 'p',
    uri_ascii => 1,
    keep_global => 0,
    punct_spacing => 1,
    lang_spacing => 1,
    number_spacing => 1,
    re_pre => qr/^pre$/i,
    re_code => qr/^code$/i,
    palt0 => { style => { "font-feature-settings" => "'palt' 0" } },
    palt1 => { style => { "font-feature-settings" => "'palt' 1" } },
    re_token => undef,
  );

  $self->verbose(0) unless defined $self->verbose;

  do {
    my ($x1, $a, $b, $e) = (1, 0.25, 0, 0.01);
    my %sp = (
      emspace   => $a * (4 - $x1) + $b,
      enspace   => $a * (2 - $x1) + $b, # p
      wordspace => $a * (1 - $x1) + $b, # wj
      thinspace => $a * (0.5 - $x1) + $b, # nj
    );
    while (my ($k, $x) = each %sp) {
      my $s = HTML::Element->new('span');
      $self->attr($s, style => { 'letter-spacing' => sprintf("%.2g", $x)."em" });
      $self->attr($s, style => { 'background-color' => '#ccc' }) if $self->verbose;
      $s->push_content(' ');
      if ($self->verbose) {
        $default{$k} = $s;
      } elsif (!defined $default{$k}) {
        $default{$k} =
          abs($x) <= $e ? ' ' :
          $x < 0 && abs($x) <= 0.5 * $a + $e ? ''  : $s;
      }
    }
  };

  for (keys %default) {
    $self->$_($default{$_}) unless defined $self->$_;
  }

  for (qw/emspace enspace wordspace thinspace/) {
    my $c = "_$_";
    no strict 'refs';
    $PUA{$self->$c} = $self->$_;
  }

}

sub InSpaces {
  return <<END;
+utf8::InSpace
+InSpace2
END
}

sub InSpace2 {
  return <<END;
+IsEmSpace
+IsEnSpace
+IsWordSpace
+IsThinSpace
END
}

sub IsEmSpace   { sprintf "%X", ord _emspace }
sub IsEnSpace   { sprintf "%X", ord _enspace }
sub IsWordSpace { sprintf "%X", ord _wordspace }
sub IsThinSpace { sprintf "%X", ord _thinspace }

sub InWestern {
  return <<END;
+InWesternCharacters
-InJapaneseCharacters
END
}

sub InNumbers {
  return <<END;
+InGroupedNumerals
-utf8::InSpace
END
}

sub InPunctuations {
  return <<END;
+InStarting
+InEnding
+InHyphens
+InMiddleDots
+utf8::InP
+utf8::InS
END
}

sub InNeutral {
  return <<END;
+InPunctuations
-InStarting
-InEnding
-InMiddleDots
END
}

sub InStartingJ {
  return <<END;
+InStarting
&InJapaneseCharacters
END
}

sub InStartingW {
  return <<END;
+InStarting
&InWesternCharacters
END
}

sub InEndingJ {
  return <<END;
+InEnding
&InJapaneseCharacters
END
}

sub InEndingW {
  return <<END;
+InEnding
&InWesternCharacters
END
}

sub InMiddleDotsJ {
  return <<END;
+InMiddleDots
&InJapaneseCharacters
END
}

sub InMiddleDotsW {
  return <<END;
+InMiddleDots
&InWesternCharacters
END
}

sub InStarting {
  return <<END;
+utf8::InPs
+utf8::InPi
END
}

sub InEnding {
  return <<END;
+utf8::InPe
+utf8::InPf
+InColon
+InFullStops
+InCommas
+InDividingPunctuationMarks
END
}

sub InJapanese {
  return <<END;
+InJapaneseCharacters
-InPunctuations
END
}

sub InJapaneseCharacters {
  # see $Config{privlib}/unicore/Blocks.txt
  (my $u = <<END) =~ s/[#;].*//gm; $u;
3000\t303F; CJK Symbols and Punctuation
3040\t309F; Hiragana
30A0\t30FF; Katakana
3190\t319F; Kanbun
31C0\t31EF; CJK Strokes
31F0\t31FF; Katakana Phonetic Extensions
3200\t32FF; Enclosed CJK Letters and Months
3300\t33FF; CJK Compatibility
3400\t4DBF; CJK Unified Ideographs Extension A
4DC0\t4DFF; Yijing Hexagram Symbols
4E00\t9FFF; CJK Unified Ideographs
F900\tFAFF; CJK Compatibility Ideographs
FE00\tFE0F; Variation Selectors
FF00\tFFEF; Halfwidth and Fullwidth Forms
20000\t2A6DF; CJK Unified Ideographs Extension B
2A700\t2B73F; CJK Unified Ideographs Extension C
2B740\t2B81F; CJK Unified Ideographs Extension D
2B820\t2CEAF; CJK Unified Ideographs Extension E
2CEB0\t2EBEF; CJK Unified Ideographs Extension F
2F800\t2FA1F; CJK Compatibility Ideographs Supplement
E0100\tE01EF; Variation Selectors Supplement
END
}

# A.1 Opening brackets (cl-01) 始め括弧類（cl-01）
sub InOpeningBrackets {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
00AB;  «	LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
2018; ‘	LEFT SINGLE QUOTATION MARK	used horizontal composition
201C; “	LEFT DOUBLE QUOTATION MARK	used horizontal composition
0028;  (	LEFT PARENTHESIS
3014; 〔	LEFT TORTOISE SHELL BRACKET
005b;  [	LEFT SQUARE BRACKET
007b;  {	LEFT CURLY BRACKET
3008; 〈	LEFT ANGLE BRACKET
300A; 《	LEFT DOUBLE ANGLE BRACKET
300C; 「	LEFT CORNER BRACKET
300E; 『	LEFT WHITE CORNER BRACKET
3010; 【	LEFT BLACK LENTICULAR BRACKET
2985; ｟	LEFT WHITE PARENTHESIS
3018; 〘	LEFT WHITE TORTOISE SHELL BRACKET
3016; 〖	LEFT WHITE LENTICULAR BRACKET
301D; 〝	REVERSED DOUBLE PRIME QUOTATION MARK	used vertical composition
FF08; （	LEFT PARENTHESIS
FF3B; ［	LEFT SQUARE BRACKET
FF5B; ｛	LEFT CURLY BRACKET
END
}

# A.2 Closing brackets (cl-02) 終わり括弧類（cl-02）
sub InClosingBrackets {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
00BB; » 	RIGHT-POINTING DOUBLE ANGLE QUOTATION MARK
2019; ’	RIGHT SINGLE QUOTATION MARK	used horizontal composition
201D; ”	RIGHT DOUBLE QUOTATION MARK	used horizontal composition
0029; ) 	RIGHT PARENTHESIS
3015; 〕	RIGHT TORTOISE SHELL BRACKET
005D; ] 	RIGHT SQUARE BRACKET
007D; } 	RIGHT CURLY BRACKET
3009; 〉	RIGHT ANGLE BRACKET
300B; 》	RIGHT DOUBLE ANGLE BRACKET
300D; 」	RIGHT CORNER BRACKET
300F; 』	RIGHT WHITE CORNER BRACKET
3011; 】	RIGHT BLACK LENTICULAR BRACKET
2986; ｠	RIGHT WHITE PARENTHESIS
3019; 〙	RIGHT WHITE TORTOISE SHELL BRACKET
3017; 〗	RIGHT WHITE LENTICULAR BRACKET
301F; 〟	LOW DOUBLE PRIME QUOTATION MARK	used vertical composition
FF09; ）	RIGHT PARENTHESIS
FF3D; ］	RIGHT SQUARE BRACKET
FF5D; ｝	RIGHT CURLY BRACKET
END
}

# A.3 Hyphens (cl-03) ハイフン類（cl-03）
sub InHyphens {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
002d; - 	HYPHEN	quarter em width
2010; ‐ 	HYPHEN	quarter em width
301C; 〜	WAVE DASH
30A0; ゠	KATAKANA-HIRAGANA DOUBLE HYPHEN	half-width
2013; – 	EN DASH	half-width
END
}

# A.4 Dividing punctuation marks (cl-04) 区切り約物（cl-04）
sub InDividingPunctuationMarks {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
0021; ！	EXCLAMATION MARK
003F; ？	QUESTION MARK
203C; ‼	DOUBLE EXCLAMATION MARK
2047; ⁇	DOUBLE QUESTION MARK
2048; ⁈	QUESTION EXCLAMATION MARK
2049; ⁉	EXCLAMATION QUESTION MARK
FF01; ！	EXCLAMATION MARK
FF1F; ？	QUESTION MARK
END
}

# A.5 Middle dots (cl-05) 中点類（cl-05）
sub InMiddleDots {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
30FB; ・	KATAKANA MIDDLE DOT
00B7; ·		Middle Dot
END
}

sub InColon {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
003A; ：	COLON
FF1A; ：	COLON
003B; ；	SEMICOLON	used horizontal composition
FF1B; ；	SEMICOLON	used horizontal composition
END
}

# A.6 Full stops (cl-06) 句点類（cl-06）
sub InFullStops {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
3002; 。	IDEOGRAPHIC FULL STOP
002E; . 	FULL STOP	used horizontal composition
FF0E; ．	FULL STOP	used horizontal composition
END
}

# A.7 Commas (cl-07) 読点類（cl-07）
sub InCommas {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
3001; 、	IDEOGRAPHIC COMMA
002C; ，	COMMA	used horizontal composition
FF0C; ，	COMMA	used horizontal composition
END
}

# A.8 Inseparable characters (cl-08) 分離禁止文字（cl-08）
sub InInseparableCharacters {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
2014; —	EM DASH	Some systems implement U+2015 HORIZONTAL BAR very similar behavior to U+2014 EM DASH
2026; …	HORIZONTAL ELLIPSIS
2025; ‥	TWO DOT LEADER
3033; 〳	VERTICAL KANA REPEAT MARK UPPER HALF	used vertical compositionU+3035 follows this
3034; 〴	VERTICAL KANA REPEAT WITH VOICED SOUND MARK UPPER HALF	used vertical compositionU+3035 follows this
3035; 〵	VERTICAL KANA REPEAT MARK LOWER HALF	used vertical composition
END
}

# A.9 Iteration marks (cl-09) 繰返し記号（cl-09）
sub InIterationMarks {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
3005; 々	IDEOGRAPHIC ITERATION MARK
303B; 〻	VERTICAL IDEOGRAPHIC ITERATION MARK
309D; ゝ	HIRAGANA ITERATION MARK
309E; ゞ	HIRAGANA VOICED ITERATION MARK
30FD; ヽ	KATAKANA ITERATION MARK
30FE; ヾ	KATAKANA VOICED ITERATION MARK
END
}

# A.10 Prolonged sound mark (cl-10) 長音記号（cl-10）

# A.11 Small kana (cl-11) 小書きの仮名（cl-11）

# A.12 Prefixed abbreviations (cl-12) 前置省略記号（cl-12）
sub InPrefixedAbbreviations {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
00A3; ￡	POUND SIGN
FFE1; ￡	POUND SIGN
0024; ＄	DOLLAR SIGN
FF04; ＄	DOLLAR SIGN
00A5; ￥	YEN SIGN
FFE5; ￥	YEN SIGN
20AC; € 	EURO SIGN
0023; ＃	NUMBER SIGN
FF03; ＃	NUMBER SIGN
2116; №	NUMERO SIGN
END
}

# A.13 Postfixed abbreviations (cl-13) 後置省略記号（cl-13）
sub InPostfixedAbbreviations {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
00B0; °	DEGREE SIGN	proportional
2032; ′	PRIME	proportional
2033; ″	DOUBLE PRIME	proportional
2103; ℃	DEGREE CELSIUS
00A2; ￠	CENT SIGN
0025; ％	PERCENT SIGN
FF05; ％	PERCENT SIGN
2030; ‰	PER MILLE SIGN
33CB; ㏋	SQUARE HP
2113; ℓ 	SCRIPT SMALL L
3303; ㌃	SQUARE AARU
330D; ㌍	SQUARE KARORII
3314; ㌔	SQUARE KIRO
3318; ㌘	SQUARE GURAMU
3322; ㌢	SQUARE SENTI
3323; ㌣	SQUARE SENTO
3326; ㌦	SQUARE DORU
3327; ㌧	SQUARE TON
332B; ㌫	SQUARE PAASENTO
3336; ㌶	SQUARE HEKUTAARU
333B; ㌻	SQUARE PEEZI
3349; ㍉	SQUARE MIRI
334A; ㍊	SQUARE MIRIBAARU
334D; ㍍	SQUARE MEETORU
3351; ㍑	SQUARE RITTORU
3357; ㍗	SQUARE WATTO
338E; ㎎	SQUARE MG
338F; ㎏	SQUARE KG
339C; ㎜	SQUARE MM
339D; ㎝	SQUARE CM
339E; ㎞	SQUARE KM
33A1; ㎡	SQUARE M SQUARED
33C4; ㏄	SQUARE CC
END
}

# A.14 Full-width ideographic space (cl-14) 和字間隔（cl-14）

# A.15 Hiragana (cl-15) 平仮名（cl-15）

# A.16 Katakana (cl-16) 片仮名（cl-16）

# A.17 Math symbols (cl-17) 等号類（cl-17）

# A.18 Math operators (cl-18) 演算記号（cl-18）

# A.19 Ideographic characters (cl-19) 漢字等（漢字以外の例）（cl-19）

# A.20 Characters as reference marks (cl-20) 合印中の文字（cl-20）

# A.21 Ornamented character complexes (cl-21) 親文字群中の文字（添え字付き）（cl-21）

# A.22 Simple-ruby character complexes (cl-22) 親文字群中の文字（熟語ルビ以外のルビ付き）（cl-22）

# A.23 Jukugo-ruby character complexes (cl-23) 親文字群中の文字（熟語ルビ付き）（cl-23）

# A.24 Grouped numerals (cl-24) 連数字中の文字（cl-24）

sub InGroupedNumerals {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
#0020; 		SPACE	quarter em width 位取りの空白
002C;		, 	COMMA 	quarter em width or half-width 位取りのコンマ
002E;		. 	FULL STOP decimal point, quarter em width or half-width 小数点
0030\t0039;	0-9
END
}

# A.25 Unit symbols (cl-25) 単位記号中の文字（cl-25）

# A.26 Western word space (cl-26) 欧文間隔（cl-26）

# A.27 Western characters (cl-27) 欧文用文字（cl-27）
sub InWesternCharacters {
  (my $u = <<END) =~ s/[#;].*//gm; $u;
0021\t007E
00A0\t00B4
00B6\t0109
010C\t010F
0111\t0113
0118\t011D
0124\t0125
0127\t0127
012A\t012B
0134\t0135
0139\t013A
013D\t013E
0141\t0144
0147\t0148
014B\t014D
0150\t0155
0158\t0165
016A\t0171
0179\t017E
0193\t0193
01C2\t01C2
01CD\t01CE
01D0\t01D2
01D4\t01D4
01D6\t01D6
01D8\t01D8
01DA\t01DA
01DC\t01DC
01F8\t01F9
01FD\t01FD
0250\t025A
025C\t025C
025E\t0261
0264\t0268
026C\t0273
0275\t0275
0279\t027B
027D\t027E
0281\t0284
0288\t028E
0290\t0292
0294\t0295
0298\t0298
029D\t029D
02A1\t02A2
02C7\t02C8
02CC\t02CC
02D0\t02D1
02D8\t02D9
02DB\t02DB
02DD\t02DE
02E5\t02E9
0300\t0304
0306\t0306
0308\t0308
030B\t030C
030F\t030F
0318\t031A
031C\t0320
0324\t0325
0329\t032A
032C\t032C
032F\t0330
0334\t0334
0339\t033D
0361\t0361
0391\t03A1
03A3\t03A9
03B1\t03C9
0401\t0401
0410\t044F
0451\t0451
1E3E\t1E3F
1F70\t1F73
2010\t2010
2013\t2014
2016\t2016
2018\t2019
201C\t201D
2020\t2022
2025\t2026
2030\t2030
2032\t2033
203E\t203F
2042\t2042
2051\t2051
20AC\t20AC
210F\t210F
2127\t2127
212B\t212B
2135\t2135
2153\t2155
2190\t2194
2196\t2199
21C4\t21C4
21D2\t21D2
21D4\t21D4
21E6\t21E9
2200\t2200
2202\t2203
2205\t2205
2207\t2209
220B\t220B
2212\t2213
221A\t221A
221D\t2220
2225\t222C
222E\t222E
2234\t2235
223D\t223D
2243\t2243
2245\t2245
2248\t2248
2252\t2252
2260\t2262
2266\t2267
226A\t226B
2276\t2277
2282\t2287
228A\t228B
2295\t2297
22A5\t22A5
22DA\t22DB
2305\t2306
2312\t2312
2318\t2318
23CE\t23CE
2423\t2423
2460\t2473
24D0\t24E9
24EB\t24FE
25A0\t25A1
25B1\t25B3
25B6\t25B7
25BC\t25BD
25C0\t25C1
25C6\t25C7
25CB\t25CB
25CE\t25D3
25E6\t25E6
25EF\t25EF
2600\t2603
2605\t2606
260E\t260E
261E\t261E
2640\t2640
2642\t2642
2660\t2667
2669\t266F
2713\t2713
2756\t2756
2776\t277F
2934\t2935
29FA\t29FB
3251\t325F
32B1\t32BF
#AC00\tD7AF; Hangul Syllables
END
}

# A.28 Warichu opening brackets (cl-28) 割注始め括弧類（cl-28）

# A.29 Warichu closing brackets (cl-29) 割注終わり括弧類（cl-29）

# A.30 Characters in tate-chu-yoko (cl-30) 縦中横中の文字（cl-30）

1;
__END__

=head1 DESCRIPTION

HTMLのテキスト(preやcodeを除く)のスペースを補正します。L<< 日本語文章
中、英単語の両端にスペースをつける人
|https://qiita.com/CodeOne/items/43d2b8e4247b020652b2 >>のような補正で
す。括弧と句読点に含まれるスペースも補正します。font-feature-settings
を使うので、cssにotfを指定する必要があります。

 body {
   font-family: "Noto Sans CJK JP", sans-serif;
 }

括弧と句読点の配置は、L<< 日本語組版処理の要件
|https://www.w3.org/TR/jlreq/ >>の 3.1.2 句読点や括弧類などの基本的な
配置方法、3.1.4 始め括弧類〜が連続する場合の配置方法に合わせました。例
として同文書の図69を示します。

=over

=item 1.

…である。」この…
句読点の後ろに終わり括弧類が連続

=item 2.

…である）。この…
終わり括弧類の後ろに句読点が連続

=item 3.

…である、「この…
読点類の後ろに始め括弧類が連続

=item 4.

…である」「この…
終わり括弧類の後ろに始め括弧類が連続

=item 5.

…である「『この…
始め括弧類の後ろに始め括弧類が連続

=item 6.

…である）」この…
終わり括弧類の後ろに終わり括弧類が連続

=item 7.

…「編集」・「校正」…
括弧類と中点類が連続

=back

=head2 Methods

=over

=item parse(I<$html>)

入力I<$html>のスペースを補正して出力します。

=item output_tag(I<$tag>)

出力をI<$tag>で囲みます。デフォルトは "p" です。
style のような属性を加えるにはリファレンスを使います。

 $ja->output_tag([ "p", style => "text-align: justify" ]);

=item lang_spacing(I<$yesno>)

欧文の語と和文がスペースで区切られていないとき、
区切りにL</wordspace>を置きます。
デフォルトは1です。

=item number_spacing(I<$yesno>)

数と和文がスペースで区切られていないとき、
区切りにL</thinspace>を置きます。
デフォルトは1です。

=item punct_spacing(I<$yesno>)

日本語の句読点や括弧等の字体のアキ (L</palt1>で詰められる) を
L</enspace>で補います。デフォルトは1です。

=item uri_ascii(I<$yesno>)

URIに使える文字をASCIIに制限します。デフォルトは1です。

=item re_token(I<$hash>)

語とそのクラスを定義します。
クラスには W (欧文)、N (数)、J (日本語) の3つがあります。
次の例は欧文を含む複雑な語を日本語のトークンにします。

 $ja->re_token({ J => qr/ Official髭男dism /x });

=item re_pre(I<$regex>)

デフォルトはC<qr/^pre$/>です。

=item re_code(I<$regex>)

デフォルトはC<qr/^code$/>です。

=item enspace(I<$html>)

二分アキです。デフォルトは20H (空白)とletter-spacingで作ります。

=item wordspace(I<$html>)

四分アキです。デフォルトは20Hです。

=item thinspace(I<$html>)

小さなスペースです。デフォルトは '' (空の文字列)です。

=item palt0(I<$html>)

デフォルトはC<< { style => { 'font-feature-settings' => '"palt" 0' } } >>です。

=item palt1(I<$html>)

デフォルトはC<< { style => { 'font-feature-settings' => '"palt" 1' } } >>です。

=item keep_global(I<$yesno>)

I<$yesno>を非0にすると、グローバル変数を開放しません。語とトークンの対
応を固定します。デフォルトは0です。(デバグ用です。)

=item verbose(I<$level>)

ヒントを出力します。デフォルトは0です。(デバグ用です。)

=back

=head2 User-Defined Character Properties

以下は、L<< 日本語組版処理の要件の文字クラス一覧
|https://www.w3.org/TR/jlreq/#character_classes >>をPerlのL<< ユーザ定
義文字特性|perlunicode/User-Defined Character Properties >>の形で定義
したものです。縦書を扱わないので、いくつか直しました。

=over

=item InClosingBrackets

L<cl-02|https://www.w3.org/TR/jlreq/#cl-02>です。
使いません。代りにC<\p{Pe}>とC<\p{Pf}>を使います。

=item InColon

L</InMiddleDots> (L<cl-05|https://www.w3.org/TR/jlreq/#cl-05>)を分けました。

=item InCommas

L<cl-07|https://www.w3.org/TR/jlreq/#cl-07>です。

=item InDividingPunctuationMarks

L<cl-04|https://www.w3.org/TR/jlreq/#cl-04>です。

=item InEnding

おわりの記号類です。C<\p{Pe}>, C<\p{Pf}>, L</InColon>,
L</InFullStops>, L</InCommas>、およびL</InDividingPunctuationMarks>で
す。

=item InEndingJ

L<InEnding>のうち日本語のフォントに含まれるもの。

=item InEndingW

L<InEnding>のうち欧文のフォントに含まれるもの。

=item InFullStops

L<cl-06|https://www.w3.org/TR/jlreq/#cl-06>です。

=item InGroupedNumerals

L<cl-24|https://www.w3.org/TR/jlreq/#cl-24>です。

=item InHyphens

L<cl-03|https://www.w3.org/TR/jlreq/#cl-03>です。

=item InInseparableCharacters

L<cl-08|https://www.w3.org/TR/jlreq/#cl-08>です。

=item InIterationMarks

L<cl-09|https://www.w3.org/TR/jlreq/#cl-09>です。
使いません。

=item InJapanese

日本語の文字L</InJapaneseCharacters>から記号類L</InPunctuations>を除い
たものです。

=item InJapaneseCharacters

$Config{privlib}/unicore/Blocks.txtからもってきました。

 3000\t303F; CJK Symbols and Punctuation
 3040\t309F; Hiragana
 30A0\t30FF; Katakana
 3190\t319F; Kanbun
 31C0\t31EF; CJK Strokes
 31F0\t31FF; Katakana Phonetic Extensions
 3200\t32FF; Enclosed CJK Letters and Months
 3300\t33FF; CJK Compatibility
 3400\t4DBF; CJK Unified Ideographs Extension A
 4DC0\t4DFF; Yijing Hexagram Symbols
 4E00\t9FFF; CJK Unified Ideographs
 20000\t2A6DF; CJK Unified Ideographs Extension B
 2A700\t2B73F; CJK Unified Ideographs Extension C
 2B740\t2B81F; CJK Unified Ideographs Extension D
 2B820\t2CEAF; CJK Unified Ideographs Extension E
 2CEB0\t2EBEF; CJK Unified Ideographs Extension F
 2F800\t2FA1F; CJK Compatibility Ideographs Supplement

=item InMiddleDots

L<cl-05|https://www.w3.org/TR/jlreq/#cl-05>の一部、横書きの中点類のみ
です。

=item InMiddleDotsJ

L</InMiddleDots>のうち日本語のフォントに含まれるもの。

=item InMiddleDotsW

L</InMiddleDots>のうち欧文のフォントに含まれるもの。

=item InNeutral

欧文の文字で、前後にスペースを追加しないもの。(入力されたスペースは除
きます。)

=item InNumbers

数の類です。L</InGroupedNumerals>からスペースを除きました。

=item InOpeningBrackets

L<cl-01|https://www.w3.org/TR/jlreq/#cl-01>です。
使いません。代わりにC<\p{Ps}>とC<\p{Pi}>を使います。

=item InPUA

PUA (L<私用面|https://ja.wikipedia.org/wiki/私用面>)です。

=item InPostfixedAbbreviations

L<cl-13|https://www.w3.org/TR/jlreq/#cl-13>です。

=item InPrefixedAbbreviations

L<cl-12|https://www.w3.org/TR/jlreq/#cl-12>です。

=item InPunctuations

すべての記号類です。

=item InSpaces

スペース類です。C<\s> (utf8::InSpace) と L</InSpace2> です。

=item InSpace2

内部スペース類です。

=item InStarting

始まりの記号類です。C<\p{Ps}>とC<\p{Pi}>です。

=item InStartingJ

L</InStarting>のうち日本語のフォントに含まれるもの。

=item InStartingW

L</InStarting>のうち欧文のフォントに含まれるもの。

=item InWestern

欧文の語を構成する文字です。L</InJapaneseCharacters>と重複せず、
L</InNumbers>を含みます。

=item InWesternCharacters

L<cl-27|https://www.w3.org/TR/jlreq/#cl-27>です。たとえば、ここに
C<AC00\tD7AF> (Hangul Syllables) を追加し、和文の中に안녕하세요と書くと
前後にスペースが付きます。

=item IsEmSpace

=item IsEnSpace

=item IsThinSpace

=item IsWordSpace

内部スペースの各文字に一致します。

=back

=head2 Global Variables

=over

=item $PUA_free

このモジュールで使用するPUA領域の始まりのアドレスです。
デフォルトは0xF0000です。

=item %PUA

語 (HTMLコード) のハッシュです。キーは語のトークンです。

=item %TOKEN

トークン (PUA から割り当てた文字コード) のハッシュです。キーは語です。

=item %CLASS

'W' (語) や 'N' (数) で分類したトークンのハッシュです。キーは分類です。

=back

=head1 LICENSE

Copyright (C) KUBO, Koichi.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

KUBO, Koichi E<lt>k@obuk.orgE<gt>

=cut
