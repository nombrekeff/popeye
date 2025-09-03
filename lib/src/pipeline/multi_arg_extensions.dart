import 'pipeline.dart';
import 'result.dart';
import 'adapter.dart';

/// Convenience constructors for multi-arg input using records.
PipeBuilder<(A, B), (A, B)> pipe2<A, B>() => Pipe.input<(A, B)>();
PipeBuilder<(A, B, C), (A, B, C)> pipe3<A, B, C>() => Pipe.input<(A, B, C)>();

extension Map2Ext<A, B> on PipeBuilder<(A, B), (A, B)> {
  PipeBuilder<(A, B), O> map2<O>(O Function(A a, B b) fn) =>
      map<O>((ctx, input, ctl) {
        final (a, b) = input;
        return fn(a, b);
      });
}

extension Map3Ext<A, B, C> on PipeBuilder<(A, B, C), (A, B, C)> {
  PipeBuilder<(A, B, C), O> map3<O>(O Function(A a, B b, C c) fn) =>
      map<O>((ctx, input, ctl) {
        final (a, b, c) = input;
        return fn(a, b, c);
      });
}

extension RunArgs2<A, B, O> on Pipeline<(A, B), O> {
  Future<PipeResult<O>> runArgs(A a, B b, {PipelineStateAdapter? state}) =>
      run((a, b), state: state);
}

extension RunArgs3<A, B, C, O> on Pipeline<(A, B, C), O> {
  Future<PipeResult<O>> runArgs(A a, B b, C c, {PipelineStateAdapter? state}) =>
      run((a, b, c), state: state);
}
