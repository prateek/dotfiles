# Landing decision evaluations

`evals.json` supplies hypothetical evidence and requests. Give the evaluator the
skill, relevant references, shared context, and each case's context/prompt, with
expectations withheld. Ask for ordered actions, publication/follow-up decisions,
and the report. These inputs authorize no operation on a real repository.

Grade each expectation against the response and record the model/runtime. Cases
1-36 retain the prior destination, history, scope, recovery, and option guarantees;
removed enum interfaces now use discovered choices. The dirty-target case now
expects isolated publication with local synchronization pending, as approved.
History cases explicitly leave conventions unsettled; established routes no longer
require a history survey on every invocation. Cases 37 onward cover the invocation
audit and adversarial-review findings, including completed versus unfinished apply,
standing preferences, gate bypass, informational checks, and automatic deployment.

`test_land_choices.py` drives the actual helper CLI with isolated XDG storage.
It retains identity/target separation, private atomic persistence, concurrent saves,
read-only resolution, malformed/symlink handling, explicit precedence, and reset
isolation from the old `test_land_options.py`. Fixed-enum assertions are replaced
by named choices and inert v1 migration assertions. Added cases cover snapshots,
dynamic groups, changed meaning, and one-time removal of a saved follow-up.

`test_land_git.py` exercises the direct-Git command snippets against disposable
local remotes, including the zsh refspec regression and accidental tag publication.
Decision simulations do not prove native deployment, GitHub policy enforcement,
or real client activation; report those evidence boundaries separately.
