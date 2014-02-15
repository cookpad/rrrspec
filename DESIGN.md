# RRRSpec Design Decisions

This document describes some design decisions made while writing RRRSpec. If you
have any question, please file an issue.

## Automatic resume on process or machine failures

RRRSpec is designed so that it can tolerate machine failures. This is because we
want to reduce the machine cost needed to execute tests by using AWS's spot
instances. Spot instance is a machine sold on the lower price compared to the
one of on-demand instances or the one of reserved instances. In return for this
discounted price, these instances are terminated without notice.

In addition to machine failures, process failures should be considered when
writing a test execution service. There are many reasons to make processes fail:
the bug in the interpreter or C-extensions, OOM Killer in the Linux systems, or
ill-behaved test or application code. For test services, the faults that make
processes fail are uncontrollable, and the services have to get ready for these
failures.

RRRSpec has a protocol to recover these failures, and you can see it in
HACKING.md. The protocol distinguishes process failures and machine failures.
This is because process failures can be detected easily compared to machine
failures, and thus we are able to recover these failures quickly. This behavior
shortens the time taken to complete a test.

For the developers interested in these areas, some recommended articles are
shown below:

* [Fundamentals of Fault-Tolerant Distributed Computing in Asynchronous Environments](http://dx.doi.org/10.1145/311531.311532)
* [Model Checking and Fault Tolerance](http://dx.doi.org/10.1007/BFb0000462)
* [The SPIN Model Checker](http://www.amazon.com/dp/0321773713/)

## Severe timeout of stuck processes

In addition to process failures, process stuck failures are also a kind of
failures in our concern. Sometimes, testing processes seem to be stuck. The only
thing that we can do as a test service is to stop it. In the most situations,
`timeout` library can do this job. Unfortunately, there is a case this library
won't work; a process is stuck in the C-extension holding GVL. If one of the
threads holds GVL, the other threads cannot run the code written in Ruby.
`timeout` library is implemented in Ruby, and it creates a thread to do some
timeout, but the created thread cannot work because another thread holds GVL.

To overcome this problem (this means it actually occurs), we create
[extreme_timeout](https://github.com/draftcode/extreme_timeout). This library
works almost same as `timeout` library except that it creates a thread that is
not controlled by the Ruby interpreter, and if the time taken to do some
computation exceeds a limit, it forcibly terminates the process. Thanks to the
fault-tolerance to process failures, the process failures caused by timeout are
taken care by RRRSpec. This type of failure occurs very frequently and it
amounts almost a hundred failures per day.

## Automatic retrial of failed tests

The more a test suite grows, the more it contains flickering tests. Flickering
tests are the tests that sometimes pass and sometimes fail. To make these test
pass, RRRSpec retries the failed tests.

There is still one problem related to this retrial feature; We cannot tell
whether a test is flickering or an implementation is flickering. In either case,
there is a bug in a test code or an application code. It seems that this retrial
feature obscures these bugs, and we should stop writing new code until these
bugs are taken away. At the same time, you might also know that this type of
bugs are very difficult to fix and that it is unrealistic for large code bases
to do that. The retrial feature makes a test pass and records which test is
flickering. We should know what it does and should use this feature carefully.

## Optimization of the test execution order

The time range taken to finish one test file is very wide; from a second to a
few minutes. If we put the largest one in the tail of the task queue, it is
executed in the last part of the test, and while executing this large test, the
other workers are waiting for this test finished. We can optimize the overall
time taken to finish all tests by avoiding this situation. RRRSpec tracks the
past results and sorts the test files by the time. This makes it execute the
large tests first, and the overall time speeds-up.

## Speculative execution of long-running tests

As we increase the concurrency, the speed is becoming saturated. One probable
bottleneck is a very large test. With such a test, test execution processes are
waiting for one process executing it. To avoid the further degradation of speed
when the test is failed after few minutes (and it is always the case), RRRSpec
speculatively execute this test in the vacant machines.
