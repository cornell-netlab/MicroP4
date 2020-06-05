+++
title = "μP4"
description = "A compiler to build dataplane of network devices using Portable, Modular and Composable programs"
+++

{{< lead >}}
TODO:
for now Abstract as overview

Languages like P4 enable flexible and efficient packet-processing using domain-specific primitives such as programmable parsers and match-action tables. Unfortunately, P4 programs tend to be monolithic and tightly coupled to the hardware architecture, which makes it hard to write programs in a portable and modular way—e.g., by composing reusable libraries of standard protocols.

To address this challenge, we present the design and implementation of a novel framework (μP4) comprising a light-weight logical architecture that abstracts away from the structure of the underlying hardware pipelines and naturally supports powerful forms of program composition. Using examples, we show how μP4 enables modular programming. We present a prototype of the μP4 compiler that generates code for multiple lower-level architectures, including Barefoot’s Tofino Native Architecture (TNA). We evaluate the overheads induced by our compiler on realistic examples.
{{< /lead >}}


## Features
<div class="row py-3 mb-5">
	<div class="col-md-4">
		<div class="card flex-row border-0">
			<div class="mt-3">
				<span class="fas fa fa-th fa-2x text-primary"></span>
			</div>
			<div class="card-body pl-2">
				<h5 class="card-title">
					Modular
				</h5>
				<p class="card-text text-muted">
					TODO: one sentence
				</p>
			</div>
		</div>
	</div>
	<div class="col-md-4">
		<div class="card flex-row border-0">
			<div class="mt-3">
				<span class="fas fa fa-puzzle-piece fa-2x text-primary"></span>
			</div>
			<div class="card-body pl-2">
				<h5 class="card-title">
					Composable
				</h5>
				<p class="card-text text-muted">
					TODO: one sentence
				</p>
			</div>
		</div>
	</div>
	<div class="col-md-4">
		<div class="card flex-row border-0">
			<div class="mt-3">
				<span class="fas fa-project-diagram fa-2x text-primary"></span>
			</div>
			<div class="card-body pl-2">
				<h5 class="card-title">
					Portable
				</h5>
				<p class="card-text text-muted">
					TODO: one sentence
				</p>
			</div>
		</div>
	</div>
</div>

