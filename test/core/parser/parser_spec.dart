library parser_spec;

import '../../_specs.dart';

// Used to test getter / setter logic.
class TestData {
  String _str = "testString";
  get str => _str;
  set str(x) => _str = x;

  method() => "testMethod";
}

class Ident {
  id(x) => x;
  doubleId(x,y) => [x,y];
}

class Mixin {}
class MixedTestData extends TestData with Mixin {
}

@proxy
class MapData implements Map {
  operator[](x) => "mapped-$x";
  containsKey(x) => true;
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
@proxy
class MixedMapData extends MapData with Mixin {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
@proxy
class InheritedMapData extends MapData {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

toBool(x) => (x is num) ? x != 0 : x == true;

main() {
  describe('parse', () {
    var scope, parser;
    beforeEach(module((Module module) {
      module.type(IncrementFilter);
      module.type(SubstringFilter);
    }));
    beforeEach(inject((Parser injectedParser) {
      parser = injectedParser;
    }));

    eval(String text) => parser(text).eval(scope, null);
    expectEval(String expr) => expect(() => eval(expr));

    beforeEach(inject((Scope rootScope) { scope = rootScope; }));

    describe('expressions', () {
      it('should parse numerical expressions', () {
        expect(eval("1")).toEqual(1);
      });


      it('should parse unary - expressions', () {
        expect(eval("-1")).toEqual(-1);
        expect(eval("+1")).toEqual(1);
      });


      it('should parse unary ! expressions', () {
        expect(eval("!true")).toEqual(!true);
      });


      it('should parse multiplicative expressions', () {
        expect(eval("3*4/2%5")).toEqual(3*4/2%5);
        expect(eval("3*4~/2%5")).toEqual(3*4~/2%5);
      });


      it('should parse additive expressions', () {
        expect(eval("3+6-2")).toEqual(3+6-2);
      });


      it('should parse relational expressions', () {
        expect(eval("2<3")).toEqual(2<3);
        expect(eval("2>3")).toEqual(2>3);
        expect(eval("2<=2")).toEqual(2<=2);
        expect(eval("2>=2")).toEqual(2>=2);
      });


      it('should parse equality expressions', () {
        expect(eval("2==3")).toEqual(2==3);
        expect(eval("2!=3")).toEqual(2!=3);
      });


      it('should parse logicalAND expressions', () {
        expect(eval("true&&true")).toEqual(true&&true);
        expect(eval("true&&false")).toEqual(true&&false);
      });


      it('should parse logicalOR expressions', () {
        expect(eval("true||true")).toEqual(true||true);
        expect(eval("true||false")).toEqual(true||false);
        expect(eval("false||false")).toEqual(false||false);
      });


      it('should parse ternary/conditional expressions', () {
        var a, b, c;
        expect(eval("7==3+4?10:20")).toEqual(true?10:20);
        expect(eval("false?10:20")).toEqual(false?10:20);
        expect(eval("5?10:20")).toEqual(toBool(5)?10:20);
        expect(eval("null?10:20")).toEqual(toBool(null)?10:20);
        expect(eval("true||false?10:20")).toEqual(true||false?10:20);
        expect(eval("true&&false?10:20")).toEqual(true&&false?10:20);
        expect(eval("true?a=10:a=20")).toEqual(true?a=10:a=20);
        expect([scope['a'], a]).toEqual([10, 10]);
        scope['a'] = a = null;
        expect(eval("b=true?a=false?11:c=12:a=13")).toEqual(
                     b=true?a=false?11:c=12:a=13);
        expect([scope['a'], scope['b'], scope['c']]).toEqual([a, b, c]);
        expect([a, b, c]).toEqual([12, 12, 12]);
      });


      it('should auto convert ints to strings', () {
        expect(eval("'str ' + 4")).toEqual("str 4");
        expect(eval("4 + ' str'")).toEqual("4 str");
        expect(eval("4 + 4")).toEqual(8);
        expect(eval("4 + 4 + ' str'")).toEqual("8 str");
        expect(eval("'str ' + 4 + 4")).toEqual("str 44");
      });
    });

    describe('error handling', () {
      var parser;

      beforeEach(inject((Parser p) {
        parser = p;
      }));

      // We only care about the error strings in the DynamicParser.
      var errStr = (x) {
        if (parser is DynamicParser) { return x; }
        return null;
      };

      // PARSER ERRORS
      it('should throw a reasonable error for unconsumed tokens', () {
        expectEval(")").toThrow('Parser Error: Unconsumed token ) at column 1 in [)]');
      });


      it('should throw on missing expected token', () {
        expectEval("a(b").toThrow('Parser Error: Missing expected ) the end of the expression [a(b]');
      });


      it('should throw on bad assignment', () {
        expectEval("5=4").toThrow('Parser Error: Expression 5 is not assignable at column 2 in [5=4]');
        expectEval("array[5=4]").toThrow('Parser Error: Expression 5 is not assignable at column 8 in [array[5=4]]');
      });


      it('should throw on non-list, non-map field access', () {
        expectEval("6[3]").toThrow(errStr('Eval Error: Attempted field access on a non-list, non-map while evaling [6[3]]'));
        expectEval("6[3]=2").toThrow(errStr('Eval Error: Attempting to set a field on a non-list, non-map while evaling [6[3]=2'));
      });


      it('should throw on undefined functions', () {
        expectEval("notAFn()").toThrow(errStr('Eval Error: Undefined function notAFn while evaling [notAFn()]'));
      });


      it('should throw on not-function function calls', () {
        expectEval("4()").toThrow(errStr('Eval Error: 4 is not a function while evaling [4()]'));
      });


      it('should throw on incorrect ternary operator syntax', () {
        expectEval("true?1").toThrow(errStr(
                'Conditional expression true?1 requires all 3 expressions'));
      });


      it('should fail gracefully when missing a function', () {
        expect(() {
          parser('doesNotExist()').eval({});
        }).toThrow('Undefined function doesNotExist');

        expect(() {
          parser('exists(doesNotExist())').eval({'exists': () => true});
        }).toThrow('Undefined function doesNotExist');

        expect(() {
          parser('doesNotExists(exists())').eval({'exists': () => true});
        }).toThrow('Undefined function doesNotExist');

        expect(() {
          parser('a[0]()').eval({'a': [4]});
        }).toThrow('a[0] is not a function');

        expect(() {
          parser('a[x()]()').eval({'a': [4], 'x': () => 0});
        }).toThrow('a[x()] is not a function');

        expect(() {
          parser('{}()').eval({});
        }).toThrow('{} is not a function');
      });


      it('should let null be null', () {
        scope['map'] = {};

        expect(eval('null')).toBe(null);
        //expect(eval('map.null')).toBe(null);
      });


      it('should behave gracefully with a null scope', () {
        expect(parser('null').eval(null)).toBe(null);
      });


      it('should pass exceptions through getters', () {
        expect(() {
          parser('boo').eval(new ScopeWithErrors());
        }).toThrow('boo to you');
      });


      it('should pass exceptions through methods', () {
        expect(() {
          parser('foo()').eval(new ScopeWithErrors());
        }).toThrow('foo to you');
      });


      it('should fail if reflected object has no property', () {
        expect(() {
          parser('notAProperty').eval(new TestData());
        }).toThrow("notAProperty");
      });
    });

    describe('setters', () {
      it('should set a field in a map', () {
        scope['map'] = {};
        eval('map["square"] = 6');
        eval('map.dot = 7');

        expect(scope['map']['square']).toEqual(6);
        expect(scope['map']['dot']).toEqual(7);
      });


      it('should set a field in a list', () {
        scope['list'] = [];
        eval('list[3] = 2');

        expect(scope['list'].length).toEqual(4);
        expect(scope['list'][3]).toEqual(2);
      });


      it('should set a field on an object', () {
        scope['obj'] = new SetterObject();
        eval('obj.field = 1');

        expect(scope['obj'].field).toEqual(1);
      });


      it('should set a setter on an object', () {
        scope['obj'] = new SetterObject();
        eval('obj.setter = 2');

        expect(scope['obj'].setterValue).toEqual(2);
      });


      it('should set a []= on an object', () {
        scope['obj'] = new OverloadObject();
        eval('obj.overload = 7');

        expect(scope['obj'].overloadValue).toEqual(7);
      });


      it('should set a field in a nested map on an object', () {
        scope['obj'] = new SetterObject();
        eval('obj.map.mapKey = 3');

        expect(scope['obj'].map['mapKey']).toEqual(3);
      });


      it('should set a field in a nested object on an object', () {
        scope['obj'] = new SetterObject();
        eval('obj.nested.field = 1');

        expect(scope['obj'].nested.field).toEqual(1);
      });


      it('should create a map for dotted acces', () {
        scope['obj'] = new SetterObject();
        eval('obj.field.key = 4');

        expect(scope['obj'].field['key']).toEqual(4);
      });


      xit('should throw a nice error for type mismatch', () {
        scope['obj'] = new SetterObject();
        expect(() {
          eval('obj.integer = "hello"');
        }).toThrow("Eval Error: Caught type 'String' is not a subtype of type 'int' of 'value'. while evaling [obj.integer = \"hello\"]");
      });
    });

    describe('test cases imported from AngularJS', () {
      //// ==== IMPORTED ITs
      it('should parse expressions', () {
        expect(eval("-1")).toEqual(-1);
        expect(eval("1 + 2.5")).toEqual(3.5);
        expect(eval("1 + -2.5")).toEqual(-1.5);
        expect(eval("1+2*3/4")).toEqual(1+2*3/4);
        expect(eval("0--1+1.5")).toEqual(0- -1 + 1.5);
        expect(eval("-0--1++2*-3/-4")).toEqual(-0- -1+ 2*-3/-4);
        expect(eval("1/2*3")).toEqual(1/2*3);
      });


      it('should parse comparison', () {
        expect(eval("false")).toBeFalsy();
        expect(eval("!true")).toBeFalsy();
        expect(eval("1==1")).toBeTruthy();
        expect(eval("1!=2")).toBeTruthy();
        expect(eval("1<2")).toBeTruthy();
        expect(eval("1<=1")).toBeTruthy();
        expect(eval("1>2")).toEqual(1>2);
        expect(eval("2>=1")).toEqual(2>=1);
        expect(eval("true==2<3")).toEqual(true == 2<3);
      });


      it('should parse logical', () {
        expect(eval("0&&2")).toEqual((0!=0)&&(2!=0));
        expect(eval("0||2")).toEqual(0!=0||2!=0);
        expect(eval("0||1&&2")).toEqual(0!=0||1!=0&&2!=0);
      });


      it('should parse ternary', () {
        var returnTrue = scope['returnTrue'] = () => true;
        var returnFalse = scope['returnFalse'] = () => false;
        var returnString = scope['returnString'] = () => 'asd';
        var returnInt = scope['returnInt'] = () => 123;
        var identity = scope['identity'] = (x) => x;
        var B = toBool;

        // Simple.
        expect(eval('0?0:2')).toEqual(B(0)?0:2);
        expect(eval('1?0:2')).toEqual(B(1)?0:2);

        // Nested on the left.
        expect(eval('0?0?0:0:2')).toEqual(B(0)?B(0)?0:0:2);
        expect(eval('1?0?0:0:2')).toEqual(B(1)?B(0)?0:0:2);
        expect(eval('0?1?0:0:2')).toEqual(B(0)?B(1)?0:0:2);
        expect(eval('0?0?1:0:2')).toEqual(B(0)?B(0)?1:0:2);
        expect(eval('0?0?0:2:3')).toEqual(B(0)?B(0)?0:2:3);
        expect(eval('1?1?0:0:2')).toEqual(B(1)?B(1)?0:0:2);
        expect(eval('1?1?1:0:2')).toEqual(B(1)?B(1)?1:0:2);
        expect(eval('1?1?1:2:3')).toEqual(B(1)?B(1)?1:2:3);
        expect(eval('1?1?1:2:3')).toEqual(B(1)?B(1)?1:2:3);

        // Nested on the right.
        expect(eval('0?0:0?0:2')).toEqual(B(0)?0:B(0)?0:2);
        expect(eval('1?0:0?0:2')).toEqual(B(1)?0:B(0)?0:2);
        expect(eval('0?1:0?0:2')).toEqual(B(0)?1:B(0)?0:2);
        expect(eval('0?0:1?0:2')).toEqual(B(0)?0:B(1)?0:2);
        expect(eval('0?0:0?2:3')).toEqual(B(0)?0:B(0)?2:3);
        expect(eval('1?1:0?0:2')).toEqual(B(1)?1:B(0)?0:2);
        expect(eval('1?1:1?0:2')).toEqual(B(1)?1:B(1)?0:2);
        expect(eval('1?1:1?2:3')).toEqual(B(1)?1:B(1)?2:3);
        expect(eval('1?1:1?2:3')).toEqual(B(1)?1:B(1)?2:3);

        // Precedence with respect to logical operators.
        expect(eval('0&&1?0:1')).toEqual(B(0)&&B(1)?0:1);
        expect(eval('1||0?0:0')).toEqual(B(1)||B(0)?0:0);

        expect(eval('0?0&&1:2')).toEqual(B(0)?0&&1:2);
        expect(eval('0?1&&1:2')).toEqual(B(0)?1&&1:2);
        expect(eval('0?0||0:1')).toEqual(B(0)?0||0:1);
        expect(eval('0?0||1:2')).toEqual(B(0)?0||1:2);

        expect(eval('1?0&&1:2')).toEqual(B(1)?B(0)&&B(1):2);
        expect(eval('1?1&&1:2')).toEqual(B(1)?B(1)&&B(1):2);
        expect(eval('1?0||0:1')).toEqual(B(1)?B(0)||B(0):1);
        expect(eval('1?0||1:2')).toEqual(B(1)?B(0)||B(1):2);

        expect(eval('0?1:0&&1')).toEqual(B(0)?1:B(0)&&B(1));
        expect(eval('0?2:1&&1')).toEqual(B(0)?2:B(1)&&B(1));
        expect(eval('0?1:0||0')).toEqual(B(0)?1:B(0)||B(0));
        expect(eval('0?2:0||1')).toEqual(B(0)?2:B(0)||B(1));

        expect(eval('1?1:0&&1')).toEqual(B(1)?1:B(0)&&B(1));
        expect(eval('1?2:1&&1')).toEqual(B(1)?2:B(1)&&B(1));
        expect(eval('1?1:0||0')).toEqual(B(1)?1:B(0)||B(0));
        expect(eval('1?2:0||1')).toEqual(B(1)?2:B(0)||B(1));

        // Function calls.
        expect(eval('returnTrue() ? returnString() : returnInt()')).toEqual(
            returnTrue() ? returnString() : returnInt());
        expect(eval('returnFalse() ? returnString() : returnInt()')).toEqual(
            returnFalse() ? returnString() : returnInt());
        expect(eval('returnTrue() ? returnString() : returnInt()')).toEqual(
            returnTrue() ? returnString() : returnInt());
        expect(eval('identity(returnFalse() ? returnString() : returnInt())')).toEqual(
            identity(returnFalse() ? returnString() : returnInt()));
      });


      it('should parse string', () {
        expect(eval("'a' + 'b c'")).toEqual("ab c");
      });


      it('should access scope', () {
        scope['a'] =  123;
        scope['b'] = {'c': 456};
        expect(eval("a")).toEqual(123);
        expect(eval("b.c")).toEqual(456);
        expect(eval("x.y.z")).toEqual(null);
      });


      it('should access classes on scope', () {
        scope['ident'] = new Ident();
        expect(eval('ident.id(6)')).toEqual(6);
        expect(eval('ident.doubleId(4,5)')).toEqual([4, 5]);
      });


      it('should resolve deeply nested paths (important for CSP mode)', () {
        scope['a'] = {'b': {'c': {'d': {'e': {'f': {'g': {'h': {'i': {'j': {'k': {'l': {'m': {'n': 'nooo!'}}}}}}}}}}}}};
        expect(eval("a.b.c.d.e.f.g.h.i.j.k.l.m.n")).toBe('nooo!');
      });


      it('should be forgiving', () {
        scope = {'a': {'b': 23}};
        expect(eval('b')).toBeNull();
        expect(eval('a.x')).toBeNull();
      });


      it('should catch NoSuchMethod', () {
        scope = {'a': {'b': 23}};
        expect(() => eval('a.b.c.d')).toThrow('NoSuchMethod');
      });


      it('should evaluate grouped expressions', () {
        expect(eval("(1+2)*3")).toEqual((1+2)*3);
      });


      it('should evaluate assignments', () {
        scope = {'g': 4, 'arr': [3,4]};

        expect(eval("a=12")).toEqual(12);
        expect(scope["a"]).toEqual(12);

        expect(eval("arr[c=1]")).toEqual(4);
        expect(scope["c"]).toEqual(1);

        expect(eval("x.y.z=123;")).toEqual(123);
        expect(scope["x"]["y"]["z"]).toEqual(123);

        expect(eval("a=123; b=234")).toEqual(234);
        expect(scope["a"]).toEqual(123);
        expect(scope["b"]).toEqual(234);
      });

      // TODO: assignment to an arr[c]
      // TODO: failed assignment
      // TODO: null statements in multiple statements


      it('should evaluate function call without arguments', () {
        scope['constN'] = () => 123;
        expect(eval("constN()")).toEqual(123);
      });

      it('should access a protected keyword on scope', () {
        scope['const'] = 3;
        expect(eval('const')).toEqual(3);
      });


      it('should evaluate function call with arguments', () {
        scope["add"] =  (a,b) {
          return a+b;
        };
        expect(eval("add(1,2)")).toEqual(3);
      });


      it('should evaluate function call from a return value', () {
        scope["val"] = 33;
        scope["getter"] = () { return () { return scope["val"]; };};
        expect(eval("getter()()")).toBe(33);
      });


      it('should evaluate methods on object', () {
        scope['obj'] = ['ABC'];
        var fn = parser("obj.elementAt(0)").bind(scope);
        expect(fn()).toEqual('ABC');
        expect(scope.$eval(fn)).toEqual('ABC');
      });


      it('should only check locals on first dereference', () {
        scope['a'] = {'b': 1};
        var locals = {'b': 2};
        var fn = parser("this['a'].b").bind(scope);
        expect(fn(locals)).toEqual(1);
      });


      it('should evaluate multiplication and division', () {
        scope["taxRate"] =  8;
        scope["subTotal"] =  100;
        expect(eval("taxRate / 100 * subTotal")).toEqual(8);
        expect(eval("taxRate ~/ 100 * subTotal")).toEqual(0);
        expect(eval("subTotal * taxRate / 100")).toEqual(8);
      });


      it('should evaluate array', () {
        expect(eval("[]").length).toEqual(0);
        expect(eval("[1, 2]").length).toEqual(2);
        expect(eval("[1, 2]")[0]).toEqual(1);
        expect(eval("[1, 2]")[1]).toEqual(2);
      });


      it('should evaluate array access', () {
        expect(eval("[1][0]")).toEqual(1);
        expect(eval("[[1]][0][0]")).toEqual(1);
        expect(eval("[]")).toEqual([]);
        expect(eval("[].length")).toEqual(0);
        expect(eval("[1, 2].length")).toEqual(2);
      });


      it('should evaluate object', () {
        expect(eval("{}")).toEqual({});
        expect(eval("{a:'b'}")).toEqual({"a":"b"});
        expect(eval("{'a':'b'}")).toEqual({"a":"b"});
        expect(eval("{\"a\":'b'}")).toEqual({"a":"b"});
      });


      it('should evaluate object access', () {
        expect(eval("{false:'WC', true:'CC'}[false]")).toEqual("WC");
      });


      it('should evaluate JSON', () {
        expect(eval("[{}]")).toEqual([{}]);
        expect(eval("[{a:[]}, {b:1}]")).toEqual([{"a":[]},{"b":1}]);
      });


      it('should evaluate multiple statements', () {
        expect(eval("a=1;b=3;a+b")).toEqual(4);
        expect(eval(";;1;;")).toEqual(1);
      });


      // skipping should evaluate object methods in correct context (this)
      // skipping should evaluate methods in correct context (this) in argument


      it('should evaluate objects on scope context', () {
        scope["a"] =  "abc";
        expect(eval("{a:a}")["a"]).toEqual("abc");
      });


      it('should evalulate objects on Scope', inject((Scope scope) {
        expect(eval(r'$id')).toEqual(scope.$id);
        expect(eval(r'$root')).toEqual(scope.$root);
        expect(eval(r'$parent')).toEqual(scope.$parent);
      }));


      it('should evaluate field access on function call result', () {
        scope["a"] =  () {
          return {'name':'misko'};
        };
        expect(eval("a().name")).toEqual("misko");
      });


      it('should evaluate field access after array access', () {
        scope["items"] =  [{}, {'name':'misko'}];
        expect(eval('items[1].name')).toEqual("misko");
      });


      it('should evaluate array assignment', () {
        scope["items"] =  [];

        expect(eval('items[1] = "abc"')).toEqual("abc");
        expect(eval('items[1]')).toEqual("abc");
        //    Dont know how to make this work....
        //    expect(eval('books[1] = "moby"')).toEqual("moby");
        //    expect(eval('books[1]')).toEqual("moby");
      });


      it('should evaluate remainder', () {
        expect(eval('1%2')).toEqual(1);
      });


      it('should evaluate sum with undefined', () {
        expect(eval('1+undefined')).toEqual(1);
        expect(eval('undefined+1')).toEqual(1);
      });


      it('should throw exception on non-closed bracket', () {
        expect(() {
          eval('[].count(');
        }).toThrow('Unexpected end of expression: [].count(');
      });


      it('should evaluate double negation', () {
        expect(eval('true')).toBeTruthy();
        expect(eval('!true')).toBeFalsy();
        expect(eval('!!true')).toBeTruthy();
        expect(eval('{true:"a", false:"b"}[!!true]')).toEqual('a');
      });


      it('should evaluate negation', () {
        expect(eval("!false || true")).toEqual(!false || true);
        expect(eval("!(11 == 10)")).toEqual(!(11 == 10));
        expect(eval("12/6/2")).toEqual(12/6/2);
      });


      it('should evaluate exclamation mark', () {
        expect(eval('suffix = "!"')).toEqual('!');
      });


      it('should evaluate minus', () {
        expect(eval("{a:'-'}")).toEqual({'a': "-"});
      });


      it('should evaluate undefined', () {
        expect(eval("undefined")).toBeNull();
        expect(eval("a=undefined")).toBeNull();
        expect(scope["a"]).toBeNull();
      });


      it('should allow assignment after array dereference', () {
        scope["obj"] = [{}];
        eval('obj[0].name=1');
        // can not be expressed in Dart expect(scope["obj"]["name"]).toBeNull();
        expect(scope["obj"][0]["name"]).toEqual(1);
      });


      it('should short-circuit AND operator', () {
        scope["run"] = () {
          throw "IT SHOULD NOT HAVE RUN";
        };
        expect(eval('false && run()')).toBe(false);
      });


      it('should short-circuit OR operator', () {
        scope["run"] = () {
          throw "IT SHOULD NOT HAVE RUN";
        };
        expect(eval('true || run()')).toBe(true);
      });


      it('should support method calls on primitive types', () {
        scope["empty"] = '';
        scope["zero"] = 0;
        scope["bool"] = false;

        // DOES NOT WORK. String.substring is not reflected. Or toString
        // expect(eval('empty.substring(0)')).toEqual('');
        // expect(eval('zero.toString()')).toEqual('0');
        // DOES NOT WORK.  bool.toString is not reflected
        // expect(eval('bool.toString()')).toEqual('false');
      });


      it('should support map getters', () {
        expect(parser('a').eval({'a': 4})).toEqual(4);
      });


      it('should support member getters', () {
        expect(parser('str').eval(new TestData())).toEqual('testString');
      });


      it('should support returning member functions', () {
        expect(parser('method').eval(new TestData())()).toEqual('testMethod');
      });


      it('should support calling member functions', () {
        expect(parser('method()').eval(new TestData())).toEqual('testMethod');
      });


      it('should support array setters', () {
        var data = {'a': [1,3]};
        expect(parser('a[1]=2').eval(data)).toEqual(2);
        expect(data['a'][1]).toEqual(2);
      });


      it('should support member field setters', () {
        TestData data = new TestData();
        expect(parser('str="bob"').eval(data)).toEqual('bob');
        expect(data.str).toEqual("bob");
      });


      it('should support member field getters from mixins', () {
        MixedTestData data = new MixedTestData();
        data.str = 'dole';
        expect(parser('str').eval(data)).toEqual('dole');
      });


      it('should support map getters from superclass', () {
       InheritedMapData mapData = new InheritedMapData();
       expect(parser('notmixed').eval(mapData)).toEqual('mapped-notmixed');
      });


      it('should support map getters from mixins', () {
        MixedMapData data = new MixedMapData();
        expect(parser('str').eval(data)).toEqual('mapped-str');
      });


      it('should parse functions for object indices', () {
        expect(parser('a[x()]()').eval({'a': [()=>6], 'x': () => 0})).toEqual(6);
      });
    });

    describe('assignable', () {
      it('should expose assignment function', () {
        var fn = parser('a');
        expect(fn.assign).toBeNotNull();
        var scope = {};
        fn.assign(scope, 123, null);
        expect(scope).toEqual({'a':123});
      });
    });

    describe('locals', () {
      it('should expose local variables', () {
        expect(parser('a').eval({'a': 6}, {'a': 1})).toEqual(1);
        expect(parser('add(a,b)').eval({'b': 1, 'add': (a, b) { return a + b; }}, {'a': 2})).toEqual(3);
      });


      it('should expose traverse locals', () {
        expect(parser('a.b').eval({'a': {'b': 6}}, {'a': {'b':1}})).toEqual(1);
        expect(parser('a.b').eval({'a': null}, {'a': {'b':1}})).toEqual(1);
        expect(parser('a.b').eval({'a': {'b': 5}}, {'a': null})).toEqual(null);
      });


      it('should work with scopes', inject((Scope scope) {
        scope.a = {'b': 6};
        expect(parser('a.b').eval(scope, {'a': {'b':1}})).toEqual(1);
      }));

      it('should expose assignment function', () {
        var fn = parser('a.b');
        expect(fn.assign).toBeNotNull();
        var scope = {};
        var locals = {"a": {}};
        fn.assign(scope, 123, locals);
        expect(scope).toEqual({});
        expect(locals["a"]).toEqual({'b':123});
      });
    });


    describe('filters', () {
      it('should call a filter', () {
        expect(eval("'Foo'|uppercase")).toEqual("FOO");
        expect(eval("'fOo'|uppercase|lowercase")).toEqual("foo");
      });

      it('should call a filter with arguments', () {
        expect(eval("1|increment:2")).toEqual(3);
      });

      it('should evaluate grouped filters', () {
        scope.name = 'MISKO';
        expect(scope.$eval('n = (name|lowercase)')).toEqual('misko');
        expect(scope.$eval('n')).toEqual('misko');
      });

      it('should parse filters', () {
        expect(() {
          scope.$eval("1|nonexistent");
        }).toThrow('No NgFilter: nonexistent found!');

        scope.offset =  3;
        expect(scope.$eval("'abcd'|substring:1:offset")).toEqual("bc");
        expect(scope.$eval("'abcd'|substring:1:3|uppercase")).toEqual("BC");
      });
    });
  });
}

class SetterObject {
  var field;
  int integer;
  var map = {};

  var nest;
  SetterObject get nested => nest != null ? nest : (nest = new SetterObject());

  var setterValue;
  void set setter(x) { setterValue = x; }
}

@proxy
class OverloadObject implements Map {
  var overloadValue;
  operator []=(String name, var value) {
    overloadValue = value;
  }
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ScopeWithErrors {
  String get boo { throw "boo to you"; }
  String foo() { throw "foo to you"; }
}

@NgFilter(name:'increment')
class IncrementFilter {
  call(a, b) => a + b;
}

@NgFilter(name:'substring')
class SubstringFilter {
  call(String str, startIndex, [endIndex]) {
    return str.substring(startIndex, endIndex);
  }
}
