import 'package:popeye/popeye.dart';


// return coordinator
//         .processSelfie(context, imageFile, coordinator.currentSelfieType)
//         .then((_) {
//           setState(() => errorText = null);
//           final nextSelfieType = coordinator.nextSelfieType();

//           if (nextSelfieType != null) {
//             setState(() {});
//           }
//           else {
//             return coordinator
//                 .verifySelfies(coordinator.currentSelfieType)
//                 .then((success) {
//                   if (success) {
//                     setState(() => faceScanSuccess = true);
//                   } else {
//                     _setError(context.l10n.errorLivenessFailed);
//                   }
//                 })
//                 .catchError((e) {
//                   coordinator.clearSelfies();
//                   _onError(e);
//                 });
//           }
//         })
//         .catchError(_onError);

// 1. Execute async futures
// 2. Continue to next pipe
// 3. Pass result to next pipe
// 4. Handle errors
// 5. Return final result

void main() {
  /// final processSelfiePipe = pipe(
  ///   processSelfie, 
  ///   getNextSelfieType.returns().then(
  ///     verifySelfies
  ///       .error(coordinator.clearSelfies)
  ///       .returns()
  ///   )
  /// ).error(_onError);
  ///
  ///
  /// final pipeResult = await processSelfiePipe(imageFile, coordinator.currentSelfieType);
  /// pipeResult.error;
  /// pipeResult.result;

  // ---------------------------------------------------------------------------
  // PSEUDOCODE: Proposed fluent async pipeline API examples (not implemented yet)
  // ---------------------------------------------------------------------------
  // Goals:
  // - Express multi‑step async flows declaratively.
  // - Reduce nested .then / try-catch boilerplate.
  // - Integrate with Flutter state (setState / ChangeNotifier) automatically.
  // - Support branching, looping, early cancel, recovery.
  // - Keep it strongly typed end‑to‑end.

  // BASIC LINEAR PIPE
  // final pipeline = Pipe.input<File>()                       // Pipeline<File, File>
  //   .map(processSelfie)                                    // (File) -> Future<SelfieData>
  //   .tap(logStep)                                          // side effect, value unchanged
  //   .then(verifyLiveness)                                  // -> Future<LivenessResult>
  //   .timeout(const Duration(seconds: 8))                   // convert timeout to error
  //   .recoverType<TimeoutException>((e, c, v) =>            // map specific error to value
  //       LivenessResult.retryable(reason: 'timeout'))
  //   .onError(logError)                                     // side-effect only
  //   .label('finalize')
  //   .map(storeVerification)                                // persist
  //   .build();
  //
  // final result = await pipeline.run(imageFile);
  // if (result.isSuccess) { /* use result.value */ }
  // else { /* show result.error */ }

  // BRANCHING / CONDITIONAL CONTINUE
  // final selfieLoop = Pipe.input<InitialSelfie>()
  //   .expandLoop(                                           // Re-run inner block while predicate true
  //     body: (p) => p
  //       .map(processSelfie)
  //       .map((d, ctx) => ctx.share('lastAngle', d.angle))
  //       .guard((d, ctx) => ctx.call(coordinator.hasMore),  // if false, exit loop
  //           otherwise: ExitLoop()),
  //     whilePredicate: (value, ctx) => coordinator.hasMore(),
  //   )
  //   .then(verifyAllSelfies)
  //   .build();

  // BRANCH WITH DIFFERENT SUB-CHAINS
  // final branchPipeline = Pipe.input<UserEvent>()
  //   .branch<UserEvent, BranchResult>(
  //     when: [
  //       Case((e) => e.type == EventType.scan,  (p) => p.map(handleScan)),
  //       Case((e) => e.type == EventType.import,(p) => p.map(handleImport)),
  //     ],
  //     orElse: (p) => p.map(handleUnknown),
  //   )
  //   .build();

  // COMPOSITION OF SMALLER PIECES
  // final preProcessing = Pipe.input<File>()
  //   .map(validateFormat)
  //   .map(normalizeOrientation)
  //   .build();
  // final analyze = Pipe.input<NormalizedImage>()
  //   .map(runModel)
  //   .map(extractFeatures)
  //   .build();
  // final full = preProcessing.thenPipeline(analyze).build();

  // STATE INTEGRATION (Flutter setState / ChangeNotifier)
  // final stateful = Pipe.input<File>()
  //   .withState(SetStateAdapter(setState, map: (phase, data, error) => {
  //       'loading': phase.isRunning,
  //       'data': data,
  //       'error': error,
  //     }))
  //   .map(processSelfie)
  //   .then(verifyLiveness)
  //   .onSuccess((value, ctx) => ctx.state.pushSnack('Liveness OK'))
  //   .onError((err, ctx) => ctx.state.pushSnack('Failed: $err'))
  //   .build();

  // EARLY CANCEL / SHORT CIRCUIT
  // .guard(predicate, otherwise: Fail(error))
  // .guard(predicate, otherwise: Skip())           // Skip a step
  // controller.cancel();                            // From inside custom step

  // CUSTOM STEP FUNCTION SHAPE
  // PipeStep<I,O>: FutureOr<O> Function(StepContext ctx, I input, StepControl ctl)
  // Gives access to ctl.emitProgress(), ctl.fail(err), ctl.cancel(), ctx.read/sharedData.

  // RACING & COMBINING (concept only)
  // .race(otherPipeline)        // First to succeed wins
  // .combine(other, (a,b) => ...) // Wait both, combine values

  // The examples above are illustrative; API names can be refined during implementation.
}
