# Pegged-Cutter

* 以下はドキュメントの代わりに(暫定的に) Qiita に投稿した記事を引用しています。

DUBパッケージ「[pegged-cutter](https://code.dlang.org/packages/pegged-cutter)」を公開しました。
[pegged-cutter](https://code.dlang.org/packages/pegged-cutter) は、[PhilippeSigaud/Pegged](https://github.com/PhilippeSigaud/Pegged) を使って生成された構文木(Parse Tree)をいい具合に整形(刈り込み)するためのユーティリティーです。どんな風に役に立つかは、この記事と後々の記事を見て感じ取っていただければと思っています。

![image.png](https://qiita-image-store.s3.amazonaws.com/0/140610/117208d7-d2f1-8ef2-e08e-c21aa8b7cb3a.png)

DUBから使えるように、https://code.dlang.org/packages/pegged-cutter に登録しました。

# それでは…例を使って説明してみます

## dub.json を用意する

[PhilippeSigaud/Pegged](https://github.com/PhilippeSigaud/Pegged) と [pegged-cutter](https://code.dlang.org/packages/pegged-cutter) を用いるための設定を以下のように dub.json に記述しておきます。


```text:dub.json
{
    "name": "test-exe",
    "targetName": "test",
    "targetType": "executable",
    "dependencies": {
        "pegged": "~>0.4.2",
        "pegged-cutter": "~>1.0.0"
    },
    "importPaths": [],
    "sourcePaths": [],
    "sourceFiles": [
        "lang.d"
    ]
}

```

説明用の例として、JavaScript風の構文を持つシェル実行環境を作ってみます。最初に、グローバル変数の定義と定義済み変数のダンプ(のみ)が行えるようにします。

## バージョン1

バージョン1では、上記2点を可能にするための文法定義を行い

```
var x = 1234;
var y = 5678;
dump;
```
というテスト用ソースコードを解析してみます。

```d:test.d(バージョン1)
import pegged.grammar;
import pegged.cutter;
import std.stdio;

enum Lang1Grammar = `
Lang1:
# Entry Point
    TopLevel        <  EvalUnit+ eoi
# Keyword List
    Keywords        <  "dump" / "var"
# Grammars
    DumpStatement   < "dump" ";"
    EvalUnit        <  VarDeclaration / DumpStatement
    Identifier      <  (!Keywords identifier)
    Integer         <~ digit+
    VarDeclaration  <  "var" Identifier "=" Integer ";"
# Spacing
    Comment1        <~ "/*" (!"*/" .)* "*/"
    Comment2        <~ "//" (!endOfLine .)* :endOfLine
    Spacing         <- (blank / Comment1 / Comment2)*
`;
mixin(grammar(Lang1Grammar));

enum Lang1Source = `
var x = 1234;
var y = 5678;
dump;
`;

void main(string[] args)
{
    ParseTree pt = Lang1(Lang1Source);
    writeln(pt);
}

```

```text:バージョン1の実行結果
Running .\test.exe
Lang1 [0, 35]["var", "x", "=", "1234", ";", "var", "y", "=", "5678", ";", "dump", ";"]
 +-Lang1.TopLevel [0, 35]["var", "x", "=", "1234", ";", "var", "y", "=", "5678", ";", "dump", ";"]
    +-Lang1.EvalUnit [0, 15]["var", "x", "=", "1234", ";"]
    |  +-Lang1.VarDeclaration [1, 15]["var", "x", "=", "1234", ";"]
    |     +-Lang1.Identifier [5, 7]["x"]
    |     +-Lang1.Integer [9, 13]["1234"]
    +-Lang1.EvalUnit [15, 29]["var", "y", "=", "5678", ";"]
    |  +-Lang1.VarDeclaration [15, 29]["var", "y", "=", "5678", ";"]
    |     +-Lang1.Identifier [19, 21]["y"]
    |     +-Lang1.Integer [23, 27]["5678"]
    +-Lang1.EvalUnit [29, 35]["dump", ";"]
       +-Lang1.DumpStatement [29, 35]["dump", ";"]
```

「バージョン1の実行結果」の構文木を見ると、<kbd>Lang1.VarDeclaration</kbd>(`var x = 1234;`等に相当)が2回、<kbd>Lang1.DumpStatement</kbd>(`dump;`に相当)が1回含まれているのがわかります。

* <kbd>Lang1.VarDeclaration</kbd> と <kbd>Lang1.DumpStatement</kbd> の上位にある <kbd>Lang1.EvalUnit</kbd> は <kbd>EvalUnit < VarDeclaration / DumpStatement</kbd> という文法定義にあるように出現する可能性のある構文が変数定義と変数ダンプのいずれか(OR)であることを示すための定義であり、ソースの内容を実行する際には不必要な階層です。
* 同様に、<kbd>Lang1.EvalUnit</kbd> の上位にある <kbd>Lang1.TopLevel</kbd> は、<kbd>TopLevel < EvalUnit+ eoi</kbd> という文法定義にあるように、<kbd>Lang1.EvalUnit</kbd> が一回以上(この例では0回を許していません)出現することを期待しています。(最後の <kbd>eoi</kbd> がないと、文法エラーがある場合に途中までの解析成功でもOKとなってしまいます。そうならないために、<kbd>eoi</kbd> を付けてソース全体で解析成功となるようにしています) 繰り返しを束ねるために親ノードが必要ですが、[PhilippeSigaud/Pegged](https://github.com/PhilippeSigaud/Pegged) では、最上位の(エントリーポイント)非終端記号に相当するノードの上に文法定義の最初に指定した「Lang1:」に対するノードが存在するので、<kbd>Lang1.TopLevel</kbd> も削除できます。

## バージョン2

バージョン2では、[pegged-cutter](https://code.dlang.org/packages/pegged-cutter) の機能を用いて上記で示した <kbd>Lang1.TopLevel</kbd> と <kbd>Lang1.EvalUnit</kbd> を削除(省略)してみます。
main関数内の2行目に追加した以下の行による効果は、構文木を writeln() で表示した際の出力(ツリー表示)で確認できます。(下記の「バージョン2の実行結果」を参照)

```
    pt.cutNodes([`Lang1.TopLevel`, `Lang1.EvalUnit`]); // バージョン2で追加
```

これで、スクリプトの実行部(ランタイム)を作る準備が整いました。バージョン3で実行部を追加してみます。

```d:test.d(バージョン2)
import pegged.grammar;
import pegged.cutter;
import std.stdio;

enum Lang1Grammar = `
Lang1:
# Entry Point
    TopLevel        <  EvalUnit+ eoi
# Keyword List
    Keywords        <  "dump" / "var"
# Grammars
    DumpStatement   < "dump" ";"
    EvalUnit        <  VarDeclaration / DumpStatement
    Identifier      <  (!Keywords identifier)
    Integer         <~ digit+
    VarDeclaration  <  "var" Identifier "=" Integer ";"
# Spacing
    Comment1        <~ "/*" (!"*/" .)* "*/"
    Comment2        <~ "//" (!endOfLine .)* :endOfLine
    Spacing         <- (blank / Comment1 / Comment2)*
`;
mixin(grammar(Lang1Grammar));

enum Lang1Source = `
var x = 1234;
var y = 5678;
dump;
`;

void main(string[] args)
{
    ParseTree pt = Lang1(Lang1Source);
    pt.cutNodes([`Lang1.TopLevel`, `Lang1.EvalUnit`]); // バージョン2で追加
    writeln(pt);
}

```

```text:バージョン2の実行結果
Running .\test.exe
Lang1 [0, 35]["var", "x", "=", "1234", ";", "var", "y", "=", "5678", ";", "dump", ";"]
 +-Lang1.VarDeclaration [1, 15]["var", "x", "=", "1234", ";"]
 |  +-Lang1.Identifier [5, 7]["x"]
 |  +-Lang1.Integer [9, 13]["1234"]
 +-Lang1.VarDeclaration [15, 29]["var", "y", "=", "5678", ";"]
 |  +-Lang1.Identifier [19, 21]["y"]
 |  +-Lang1.Integer [23, 27]["5678"]
 +-Lang1.DumpStatement [29, 35]["dump", ";"]
```

## バージョン3

バージョン3では、(実行上のノイズとなる)不要なノードが取り除かれた構文木を読みながら実際の処理を実行する部分(ランタイム)を記述します。

```d:test.d(バージョン3)
import pegged.grammar;
import pegged.cutter;
import std.conv; // バージョン3で追加
import std.stdio;

enum Lang1Grammar = `
Lang1:
# Entry Point
    TopLevel        <  EvalUnit+ eoi
# Keyword List
    Keywords        <  "dump" / "var"
# Grammars
    DumpStatement   < "dump" ";"
    EvalUnit        <  VarDeclaration / DumpStatement
    Identifier      <  (!Keywords identifier)
    Integer         <~ digit+
    VarDeclaration  <  "var" Identifier "=" Integer ";"
# Spacing
    Comment1        <~ "/*" (!"*/" .)* "*/"
    Comment2        <~ "//" (!endOfLine .)* :endOfLine
    Spacing         <- (blank / Comment1 / Comment2)*
`;
mixin(grammar(Lang1Grammar));

enum Lang1Source = `
var x = 1234;
var y = 5678;
dump;
`;

void main(string[] args)
{
    ParseTree pt = Lang1(Lang1Source);
    pt.cutNodes([`Lang1.TopLevel`, `Lang1.EvalUnit`]); // バージョン2で追加
    writeln(pt);
    // これ以降を追加(バージョン3)
    long[string] var_tbl;
    for (size_t i = 0; i < pt.children.length; i++)
    {
        ParseTree* unit = &(pt.children[i]);
        writeln(`[EXECUTE] `, unit.name);
        switch (unit.name)
        {
        case `Lang1.VarDeclaration`:
            {
                string var_name = unit.children[0].matches[0];
                writeln(`    `, var_name);
                long var_value = to!long(unit.children[1].matches[0]);
                writeln(`    `, var_value);
                var_tbl[var_name] = var_value;
            }
            break;
        case `Lang1.DumpStatement`:
            {
                writeln(`    `, var_tbl);
            }
            break;
        case `Lang1.StatementBlock`:
            break;
        default:
            break;
        }
    }
}

```

```text:バージョン3の実行結果
Running .\test.exe
Lang1 [0, 35]["var", "x", "=", "1234", ";", "var", "y", "=", "5678", ";", "dump", ";"]
 +-Lang1.VarDeclaration [1, 15]["var", "x", "=", "1234", ";"]
 |  +-Lang1.Identifier [5, 7]["x"]
 |  +-Lang1.Integer [9, 13]["1234"]
 +-Lang1.VarDeclaration [15, 29]["var", "y", "=", "5678", ";"]
 |  +-Lang1.Identifier [19, 21]["y"]
 |  +-Lang1.Integer [23, 27]["5678"]
 +-Lang1.DumpStatement [29, 35]["dump", ";"]

[EXECUTE] Lang1.VarDeclaration
    x
    1234
[EXECUTE] Lang1.VarDeclaration
    y
    5678
[EXECUTE] Lang1.DumpStatement
    ["x":1234, "y":5678]
```

## バージョン4

バージョン4では、不要なノードを文法定義で予め指定しておく方法を紹介します。

* <kbd>EvalUnit < VarDeclaration / DumpStatement</kbd> という文法定義の「EvalUnit」という名前の先頭にアンダースコアを付けて「_EvalUnit」にします。具体的には、<kbd>\_EvalUnit < VarDeclaration / DumpStatement</kbd> という風に変更します。
* 同様に、<kbd>TopLevel < EvalUnit+ eoi</kbd> の部分も変更します。「TopLevel」の部分だけでなく <kbd>\_TopLevel < \_EvalUnit+ eoi</kbd> のように右辺に含まれる「EvalUnit」の部分にもアンダースコアを付けるのをお忘れなく。

```d:test.d(バージョン4)
import pegged.grammar;
import pegged.cutter;
import std.conv; // バージョン3で追加
import std.stdio;

enum Lang1Grammar = `
Lang1:
# Entry Point
    _TopLevel       <  _EvalUnit+ eoi  # バージョン4で変更
# Keyword List
    Keywords        <  "dump" / "var"
# Grammars
    DumpStatement   < "dump" ";"
    _EvalUnit       <  VarDeclaration / DumpStatement  # バージョン4で変更
    Identifier      <  (!Keywords identifier)
    Integer         <~ digit+
    VarDeclaration  <  "var" Identifier "=" Integer ";"
# Spacing
    Comment1        <~ "/*" (!"*/" .)* "*/"
    Comment2        <~ "//" (!endOfLine .)* :endOfLine
    Spacing         <- (blank / Comment1 / Comment2)*
`;
mixin(grammar(Lang1Grammar));

enum Lang1Source = `
var x = 1234;
var y = 5678;
dump;
`;

void main(string[] args)
{
    ParseTree pt = Lang1(Lang1Source);
    // pt.cutNodes([`Lang1.TopLevel`, `Lang1.EvalUnit`]); // バージョン2で追加⇒バージョン4で削除
    pt.cutNodes(); // バージョン4で追加
    writeln(pt);
    // これ以降を追加(バージョン3)
    long[string] var_tbl;
    for (size_t i = 0; i < pt.children.length; i++)
    {
        ParseTree* unit = &(pt.children[i]);
        writeln(`[EXECUTE] `, unit.name);
        switch (unit.name)
        {
        case `Lang1.VarDeclaration`:
            {
                string var_name = unit.children[0].matches[0];
                writeln(`    `, var_name);
                long var_value = to!long(unit.children[1].matches[0]);
                writeln(`    `, var_value);
                var_tbl[var_name] = var_value;
            }
            break;
        case `Lang1.DumpStatement`:
            {
                writeln(`    `, var_tbl);
            }
            break;
        case `Lang1.StatementBlock`:
            break;
        default:
            break;
        }
    }
}

```

バージョン4の実行結果は、「バージョン3の実行結果」と同じなので省略します。

## 最後に

* `pt.cutNodes();` を実行する前にも `writeln(pt);` を読んでおいても問題ありません。ノードを削除する前のオリジナルの構文木も確認したい場合は、そのようにしてください。
* 今回紹介した機能ほど強力ではありませんが、もう一つ機能がありますが今回はその説明は割愛します。
* Linux と Windows で動作する JavaScript風スクリプト言語(主にBashやWindowsのCMD.exe/CScript.exeに相当する機能を実現する)を D言語+[PhilippeSigaud/Pegged](https://github.com/PhilippeSigaud/Pegged) で書く手順を後程ご紹介したいと思っています。
