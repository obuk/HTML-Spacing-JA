# NAME

HTML::Spacing::JA - arrange spacing in ja text

# SYNOPSIS

    use HTML::Spacing::JA;
    $ja = HTML::Spacing::JA->new();
    $output = $ja->parse($input);

# DESCRIPTION

HTMLのテキスト(preやcodeを除く)のスペースを補正します。[日本語文章
中、英単語の両端にスペースをつける人
](https://qiita.com/CodeOne/items/43d2b8e4247b020652b2)のような補正で
す。括弧と句読点に含まれるスペースも補正します。font-feature-settings
を使うので、cssにotfを指定する必要があります。

    body {
      font-family: "Noto Sans CJK JP", sans-serif;
    }

括弧と句読点の配置は、[日本語組版処理の要件
](https://www.w3.org/TR/jlreq/)の 3.1.2 句読点や括弧類などの基本的な
配置方法、3.1.4 始め括弧類〜が連続する場合の配置方法に合わせました。例
として同文書の図69を示します。

1. …である。」この…
句読点の後ろに終わり括弧類が連続
2. …である）。この…
終わり括弧類の後ろに句読点が連続
3. …である、「この…
読点類の後ろに始め括弧類が連続
4. …である」「この…
終わり括弧類の後ろに始め括弧類が連続
5. …である「『この…
始め括弧類の後ろに始め括弧類が連続
6. …である）」この…
終わり括弧類の後ろに終わり括弧類が連続
7. …「編集」・「校正」…
括弧類と中点類が連続

## Methods

- parse(_$html_)

    入力_$html_のスペースを補正して出力します。

- output\_tag(_$tag_)

    出力を_$tag_で囲みます。デフォルトは "p" です。
    style のような属性を加えるにはリファレンスを使います。

        $ja->output_tag([ "p", style => "text-align: justify" ]);

- lang\_spacing(_$yesno_)

    欧文の語と和文がスペースで区切られていないとき、
    区切りに["wordspace"](#wordspace)を置きます。
    デフォルトは1です。

- number\_spacing(_$yesno_)

    数と和文がスペースで区切られていないとき、
    区切りに["thinspace"](#thinspace)を置きます。
    デフォルトは1です。

- punct\_spacing(_$yesno_)

    日本語の句読点や括弧等の字体のアキ (["palt1"](#palt1)で詰められる) を
    ["enspace"](#enspace)で補います。デフォルトは1です。

- uri\_ascii(_$yesno_)

    URIに使える文字をASCIIに制限します。デフォルトは1です。

- re\_token(_$hash_)

    語とそのクラスを定義します。
    クラスには W (欧文)、N (数)、J (日本語) の3つがあります。
    次の例は欧文を含む複雑な語を日本語のトークンにします。

        $ja->re_token({ J => qr/ Official髭男dism /x });

- re\_pre(_$regex_)

    デフォルトは`qr/^pre$/`です。

- re\_code(_$regex_)

    デフォルトは`qr/^code$/`です。

- enspace(_$html_)

    二分アキです。デフォルトは20H (空白)とletter-spacingで作ります。

- wordspace(_$html_)

    四分アキです。デフォルトは20Hです。

- thinspace(_$html_)

    小さなスペースです。デフォルトは '' (空の文字列)です。

- palt0(_$html_)

    デフォルトは`{ style => { 'font-feature-settings' => '"palt" 0' } }`です。

- palt1(_$html_)

    デフォルトは`{ style => { 'font-feature-settings' => '"palt" 1' } }`です。

- keep\_global(_$yesno_)

    _$yesno_を非0にすると、グローバル変数を開放しません。語とトークンの対
    応を固定します。デフォルトは0です。(デバグ用です。)

- verbose(_$level_)

    ヒントを出力します。デフォルトは0です。(デバグ用です。)

## User-Defined Character Properties

以下は、[日本語組版処理の要件の文字クラス一覧
](https://www.w3.org/TR/jlreq/#character_classes)をPerlの[ユーザ定
義文字特性](https://metacpan.org/pod/perlunicode#User-Defined-Character-Properties)の形で定義
したものです。縦書を扱わないので、いくつか直しました。

- InClosingBrackets

    [cl-02](https://www.w3.org/TR/jlreq/#cl-02)です。
    使いません。代りに`\p{Pe}`と`\p{Pf}`を使います。

- InColon

    ["InMiddleDots"](#inmiddledots) ([cl-05](https://www.w3.org/TR/jlreq/#cl-05))を分けました。

- InCommas

    [cl-07](https://www.w3.org/TR/jlreq/#cl-07)です。

- InDividingPunctuationMarks

    [cl-04](https://www.w3.org/TR/jlreq/#cl-04)です。

- InEnding

    おわりの記号類です。`\p{Pe}`, `\p{Pf}`, ["InColon"](#incolon),
    ["InFullStops"](#infullstops), ["InCommas"](#incommas)、および["InDividingPunctuationMarks"](#individingpunctuationmarks)で
    す。

- InEndingJ

    [InEnding](https://metacpan.org/pod/InEnding)のうち日本語のフォントに含まれるもの。

- InEndingW

    [InEnding](https://metacpan.org/pod/InEnding)のうち欧文のフォントに含まれるもの。

- InFullStops

    [cl-06](https://www.w3.org/TR/jlreq/#cl-06)です。

- InGroupedNumerals

    [cl-24](https://www.w3.org/TR/jlreq/#cl-24)です。

- InHyphens

    [cl-03](https://www.w3.org/TR/jlreq/#cl-03)です。

- InInseparableCharacters

    [cl-08](https://www.w3.org/TR/jlreq/#cl-08)です。

- InIterationMarks

    [cl-09](https://www.w3.org/TR/jlreq/#cl-09)です。
    使いません。

- InJapanese

    日本語の文字["InJapaneseCharacters"](#injapanesecharacters)から記号類["InPunctuations"](#inpunctuations)を除い
    たものです。

- InJapaneseCharacters

    すべての日本語の文字です。異字体のセレクタも含みます。

- InMiddleDots

    [cl-05](https://www.w3.org/TR/jlreq/#cl-05)の一部、横書きの中点類のみ
    です。

- InMiddleDotsJ

    ["InMiddleDots"](#inmiddledots)のうち日本語のフォントに含まれるもの。

- InMiddleDotsW

    ["InMiddleDots"](#inmiddledots)のうち欧文のフォントに含まれるもの。

- InNeutral

    欧文の文字で日本語との境界にスペースを追加しないもの。
    (入力されたスペースは除きます。)

- InNumbers

    数の類です。["InGroupedNumerals"](#ingroupednumerals)からスペースを除きました。

- InOpeningBrackets

    [cl-01](https://www.w3.org/TR/jlreq/#cl-01)です。
    使いません。代わりに`\p{Ps}`と`\p{Pi}`を使います。

- InPUA

    PUA ([私用面](https://ja.wikipedia.org/wiki/私用面))です。

- InPostfixedAbbreviations

    [cl-13](https://www.w3.org/TR/jlreq/#cl-13)です。

- InPrefixedAbbreviations

    [cl-12](https://www.w3.org/TR/jlreq/#cl-12)です。

- InPunctuations

    すべての記号類です。

- InSpaces

    スペース類です。`\s` (utf8::IsSpace) と ["InSpace2"](#inspace2) です。

- InSpace2

    内部スペース類です。

- InStarting

    始まりの記号類です。`\p{Ps}`と`\p{Pi}`です。

- InStartingJ

    ["InStarting"](#instarting)のうち日本語のフォントに含まれるもの。

- InStartingW

    ["InStarting"](#instarting)のうち欧文のフォントに含まれるもの。

- InWestern

    欧文の語を構成する文字です。["InJapaneseCharacters"](#injapanesecharacters)と重複せず、
    ["InNumbers"](#innumbers)を含みます。

- InWesternCharacters

    [cl-27](https://www.w3.org/TR/jlreq/#cl-27)です。たとえば、ここに
    `AC00\tD7AF` (Hangul Syllables) を追加し、和文の中に안녕하세요と書くと
    前後にスペースが付きます。

- IsEmSpace
- IsEnSpace
- IsThinSpace
- IsWordSpace

    内部スペースの各文字に一致します。

## Global Variables

- $PUA\_free

    このモジュールで使用するPUA領域の始まりのアドレスです。
    デフォルトは1000000です。

- %PUA

    語 (HTMLコード) のハッシュです。キーは語のトークンです。

- %TOKEN

    トークン (PUA から割り当てた文字コード) のハッシュです。キーは語です。

- %CLASS

    'W' (語) や 'N' (数) で分類したトークンのハッシュです。キーは分類です。

# LICENSE

Copyright (C) KUBO, Koichi.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

KUBO, Koichi <k@obuk.org>
