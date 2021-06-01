(* Cut Elimination in Proof Nets *)

From Coq Require Import Bool Wf_nat.
From OLlibs Require Import dectype Permutation_Type_more.
From mathcomp Require Import all_ssreflect zify.
From GraphTheory Require Import preliminaries mgraph setoid_bigop structures bij.

From Yalla Require Export graph_more mll_prelim mll_def mll_correct.

Import EqNotations.

Set Mangle Names.
Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.
Set Bullet Behavior "Strict Subproofs".


Section Atoms.

(** A set of atoms for building formulas *)
Context { atom : DecType }.
(* TODO meilleur moyen de récupérer les notations *)
Notation formula := (@formula atom).
Notation ll := (@ll atom).
Notation base_graph := (graph (flat rule) (flat formula)).
Notation graph_left := (@graph_left atom).
Notation graph_data := (@graph_data atom).
Notation geos := (@geos atom).
Notation proof_structure := (@proof_structure atom).
Notation proof_net := (@proof_net atom).
Infix "≃l" := iso_left (at level 79).


(** * Axiom - cut reduction *)
Definition red_ax_graph_1 (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : base_graph :=
  G ∔ [source (other_cut Hcut) , dual (elabel e) , target (other_ax Hax)].

Definition red_ax_graph (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : base_graph :=
  induced ([set: red_ax_graph_1 Hcut Hax] :\ (source e) :\ (target e)).

Lemma red_ax_degenerate_source (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) :
  source e = source (other_cut Hcut) <-> other_cut Hcut = other_ax Hax.
Proof.
  split; intro H.
  - apply other_ax_eq.
    rewrite H. splitb.
    apply /eqP; apply other_cut_in_neq.
  - rewrite H.
    by destruct (other_ax_in_neq Hax) as [-> _].
Qed.

Lemma red_ax_degenerate_target (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) :
  target e = target (other_ax Hax) <-> other_cut Hcut = other_ax Hax.
Proof.
  split; intro H.
  - symmetry; apply other_cut_eq.
    rewrite H. splitb.
    apply /eqP; apply other_ax_in_neq.
  - rewrite -H.
    by destruct (other_cut_in_neq Hcut) as [-> _].
Qed.

Lemma red_ax_degenerate_None (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) :
  None \notin edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e)
  <-> other_cut Hcut = other_ax Hax.
Proof.
  rewrite !in_set; cbn. split.
  - move => /nandP[/nandP[/negPn /eqP H | /nandP[/negPn /eqP H | //]]
                 | /nandP[/negPn /eqP H | /nandP[/negPn /eqP H | //]]].
    + assert (Hf := p_deg_out (target e)).
      rewrite Hcut in Hf; cbn in Hf.
      assert (Hdone : other_cut Hcut \in set0) by by rewrite -(cards0_eq Hf) in_set H.
      contradict Hdone; by rewrite in_set.
    + by apply red_ax_degenerate_source.
    + by apply red_ax_degenerate_target.
    + assert (Hf := p_deg_in (source e)).
      rewrite Hax in Hf; cbn in Hf.
      assert (Hdone : other_ax Hax \in set0) by by rewrite -(cards0_eq Hf) in_set H.
      contradict Hdone; by rewrite in_set.
    - move => ->.
      destruct (other_ax_in_neq Hax) as [-> _].
      caseb.
Qed.


Definition red_ax_left_1 (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : red_ax_graph_1 Hcut Hax -> edge (red_ax_graph_1 Hcut Hax) :=
  fun (v : red_ax_graph_1 Hcut Hax) =>
    if (left v == e) || (left v == other_cut Hcut) || (left v == other_ax Hax) then
      if source e == source (other_cut Hcut) then Some (pick_edge_at v)
      else None
    else Some (left v).

Lemma red_ax_consistent_left (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) :
  let S := [set: red_ax_graph_1 Hcut Hax] :\ (source e) :\ (target e) in
  forall (v : red_ax_graph Hcut Hax), red_ax_left_1 (val v) \in edge_set S.
Proof.
  intros S [v Hv].
  rewrite !in_set /red_ax_left_1; cbn.
  destruct (other_cut_in_neq Hcut) as [Htc Hneqc];
  destruct (other_ax_in_neq Hax) as [Hsa Hneqa].
  assert ((forall a, source a != target e) /\ forall a, target a != source e) as [? ?].
  { split; intro a; apply /eqP => Hc.
    1: assert (Hf := p_deg_out (target e)).
    2: assert (Hf := p_deg_in (source e)).
    all: rewrite ?Hcut ?Hax in Hf; cbn in Hf.
    all: assert (Hf' : a \in set0) by by rewrite -(cards0_eq Hf) in_set Hc.
    all: contradict Hf'; by rewrite in_set. }
  assert (Hm : source e = source (other_cut Hcut) -> forall b b',
    endpoint b (pick_edge_at v) != endpoint b' (other_cut Hcut)).
  { intros Hs b b'; apply /eqP => Hc.
    assert (Hc' : pick_edge_at v \in edges_at_outin b (endpoint b' e)) by
      (destruct b'; by rewrite in_set Hc ?Htc ?Hs).
    destruct (red_ax_degenerate_source Hcut Hax) as [Ho _].
    specialize (Ho Hs).
    contradict Hv; apply /negP.
    assert (Hvin := pick_edge_at_some v).
    revert Hvin; rewrite !in_set; move => /orP[/eqP Heq | /eqP Heq];
    destruct b, b';
    apply /nandP; rewrite andb_true_r !negb_involutive.
    all: try (contradict Hc'; apply /negP; by rewrite in_set).
    all: revert Hc'; rewrite ?other_cut_set ?other_ax_set !in_set; move => /orP[/eqP Hd | /eqP Hd];
      rewrite -Heq Hd ?Hs -?Htc ?Ho; caseb. }
  assert (Hm2 : source e <> source (other_cut Hcut) -> target (other_ax Hax) != target e).
  { intro Hs; apply /eqP => Hc.
    enough (Hdone : other_cut Hcut = other_ax Hax) by by rewrite Hdone Hsa in Hs.
    assert (Hm2 : other_ax Hax \in edges_at_in (target e)) by by rewrite in_set Hc.
    revert Hm2; rewrite other_cut_set !in_set; move => /orP[/eqP Hd | /eqP Hd //].
    contradict Hd; apply /eqP; apply other_ax_in_neq. }
  splitb; case_if.
  all: try (apply /eqP; by apply nesym).
  all: try (rewrite -?Htc; by apply Hm).
  all: try by apply Hm2.
  - apply /eqP => Hc.
    assert (Hf : left v \in edges_at_out (source e)) by by rewrite in_set Hc.
    contradict Hf; apply /negP.
    rewrite other_ax_set !in_set.
    splitb; by apply /eqP.
  - apply /eqP => Hc.
    assert (Hf : left v \in edges_at_in (target e)) by by rewrite in_set Hc.
    contradict Hf; apply /negP.
    rewrite other_cut_set !in_set.
    splitb; by apply /eqP.
Qed. (* TODO essayer de simplifier (ça et les autres preuves de cette partie red) *)

Definition red_ax_left (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : red_ax_graph Hcut Hax -> edge (red_ax_graph Hcut Hax) :=
  fun v => Sub (red_ax_left_1 (val v)) (red_ax_consistent_left v).

Definition red_ax_graph_left (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : graph_left := {|
  graph_of := red_ax_graph Hcut Hax;
  left := @red_ax_left _ _ _ _;
  |}.


Lemma red_ax_consistent_order (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) :
  all (pred_of_set ([set: red_ax_graph_1 Hcut Hax] :\ (source e) :\ (target e))) (order G).
Proof.
  apply /allP => v Hv.
  assert (Hl : vlabel v = concl_l) by by apply p_order.
  repeat (apply /setD1P; split); trivial.
  all: apply /eqP => Hc; contradict Hl; by rewrite Hc ?Hcut ?Hax.
Qed.

Definition red_ax_order (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : seq (red_ax_graph Hcut Hax) :=
  sval (all_sigP (red_ax_consistent_order Hcut Hax)).

Definition red_ax_graph_data (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : graph_data := {|
  graph_left_of := red_ax_graph_left Hcut Hax;
  order := red_ax_order _ _;
  |}.

Definition red_ax_transport (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) (b : bool) (v : red_ax_graph_data Hcut Hax) :=
  fun (a : edge (red_ax_graph_data Hcut Hax)) => match val a with
  | None => if b then other_ax Hax else other_cut Hcut
  | Some a' => a'
  end.
Notation red_ax_transport_out := (@red_ax_transport _ _ _ _ false).
Notation red_ax_transport_in := (@red_ax_transport _ _ _ _ true).

Lemma red_ax_transport_inj (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) (b : bool) (v : red_ax_graph_data Hcut Hax) :
  {in edges_at_outin b v &, injective (@red_ax_transport _ _ Hcut Hax b v)}.
Proof.
  destruct (other_cut_in_neq Hcut) as [Hc0 _].
  destruct (other_ax_in_neq Hax) as [Ha0 _].
  destruct v as [v Hv]; intros [a A] [a' A'].
  rewrite !in_set /red_ax_transport; cbn; rewrite !SubK.
  move => /eqP ? /eqP ? ?; subst; apply /eqP; rewrite sub_val_eq SubK.
  destruct a as [a | ], a' as [a' | ]; subst; trivial;
  [contradict A | contradict A']; apply /negP.
  all: destruct b; rewrite !in_set /= ?Ha0 ?Hc0; caseb.
Qed.

Lemma red_ax_transport_edges (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) (b : bool) (v : G)
  (Hv : v \in [set: red_ax_graph_1 Hcut Hax] :\ (source e) :\ (target e)) :
  edges_at_outin b v =
  [set red_ax_transport b (Sub v Hv) a | a in edges_at_outin b (Sub v Hv : red_ax_graph_data Hcut Hax)].
Proof.
  assert ((forall a, source a != target e) /\ forall a, target a != source e) as [? ?].
  { split; intro a; apply /eqP; intro Ha;
    [assert (Hf := p_deg_out (target e)) | assert (Hf := p_deg_in (source e))].
    all: rewrite ?Hcut ?Hax in Hf; cbn in Hf.
    all: assert (Hdone : a \in set0) by by rewrite -(cards0_eq Hf) in_set Ha.
    all: contradict Hdone; by rewrite in_set. }
  assert (v != source e /\ v != target e) as [Hvs Hvt]
    by (revert Hv; rewrite !in_set; by move => /andP[? /andP[? _]]).
  destruct (other_cut_in_neq Hcut) as [Hc0 Hc1].
  destruct (other_ax_in_neq Hax) as [Ha0 Ha1].
  apply /setP => a.
  rewrite Imset.imsetE !in_set.
  symmetry; apply /imageP; case_if.
  - assert (a <> e) by
      by (intro Hc; destruct b; subst; by rewrite_all eq_refl).
    destruct (eq_comparable a (other_cut Hcut)) as [Heqc | Hneqc];
    [ | destruct (eq_comparable a (other_ax Hax)) as [Heqa | Hneqa]]; subst.
    + destruct b.
      { contradict Hvt; apply /negP/negPn/eqP.
        apply other_cut_in_neq. }
      assert (Hn : None \in edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e)).
      { rewrite !in_set; cbn. splitb.
        apply /eqP => Hf.
        assert (Hin : other_ax Hax \in edges_at_in (target e))
          by by rewrite in_set Hf.
        revert Hin. rewrite other_cut_set !in_set. move => /orP[/eqP Hin | /eqP Hin].
        - contradict Hin; apply /eqP.
          apply other_ax_in_neq.
        - contradict Hvs; apply /negP/negPn/eqP.
          by rewrite -Hin Ha0. }
      exists (Sub None Hn); trivial.
      by rewrite !in_set; cbn.
    + destruct b.
      2:{ contradict Hvs; apply /negP/negPn/eqP.
          apply other_ax_in_neq. }
      assert (Hn : None \in edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e)).
      { rewrite !in_set; cbn. splitb.
        apply /eqP => Hf.
        assert (Hin : other_cut Hcut \in edges_at_out (source e))
          by by rewrite in_set Hf.
        revert Hin. rewrite other_ax_set !in_set. move => /orP[/eqP Hin | /eqP Hin].
        - contradict Hin; by apply /eqP.
        - by rewrite Hin in Hneqc. }
      exists (Sub None Hn); trivial.
      by rewrite !in_set; cbn.
    + assert (Ha : Some a \in edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e)).
      { rewrite !in_set; cbn.
        splitb; destruct b; try by [].
        - apply /eqP => Hf.
          assert (Hc : a \in edges_at_out (source e)) by by rewrite in_set Hf.
          revert Hc; rewrite other_ax_set !in_set; by move => /orP[/eqP ? | /eqP ?].
        - apply /eqP => Hf.
          assert (Hc : a \in edges_at_in (target e)) by by rewrite in_set Hf.
          revert Hc; rewrite other_cut_set !in_set; by move => /orP[/eqP ? | /eqP ?]. }
      exists (Sub (Some a) Ha); trivial.
      by rewrite !in_set; cbn.
  - intros [[x Hxin] Hx Hxx].
    rewrite /red_ax_transport SubK in Hxx. subst.
    contradict Hx; apply /negP.
    rewrite in_set; cbn; rewrite !SubK; apply /eqP.
    by destruct x, b.
Qed.
Notation red_ax_transport_edges_at_out := (@red_ax_transport_edges _ _ _ _ false).
Notation red_ax_transport_edges_at_in := (@red_ax_transport_edges _ _ _ _ true).

Lemma red_ax_transport_left (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) (v : G)
  (Hv : v \in [set: red_ax_graph_1 Hcut Hax] :\ (source e) :\ (target e)) :
  vlabel v = ⊗ \/ vlabel v = ⅋ ->
  red_ax_transport_in (Sub v Hv) (left (Sub v Hv : red_ax_graph_data Hcut Hax)) = left v.
Proof.
  intro Hl. cbn. rewrite /red_ax_transport /red_ax_left /red_ax_left_1 !SubK.
  assert (left v <> e).
  { intros ?; subst e.
    contradict Hv; apply /negP.
    rewrite !in_set left_e; caseb. }
  assert (left v <> other_cut Hcut).
  { intro Hf.
    assert (Hc := left_e Hl); contradict Hc.
    rewrite Hf.
    destruct (other_cut_in_neq Hcut) as [-> _].
    intros ?; subst v.
    clear - Hl Hcut; contradict Hcut.
    by destruct Hl as [-> | ->]. }
  case_if.
  enough (left v = other_cut Hcut) by by [].
  replace (left v) with (other_ax Hax); symmetry.
  by apply (red_ax_degenerate_source Hcut Hax).
Qed.


Lemma red_ax_p_deg (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : proper_degree (red_ax_graph_data Hcut Hax).
Proof.
  unfold proper_degree, red_ax_graph_data.
  intros b [v Hv]; cbn.
  rewrite -(p_deg b v) (red_ax_transport_edges _ Hv) card_in_imset //.
  apply red_ax_transport_inj.
Qed.

Lemma red_ax_p_left (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : proper_left (red_ax_graph_data Hcut Hax).
Proof.
  unfold proper_left, red_ax_graph_data.
  intros [v Hv] Hl; cbn in *.
  assert (H := p_left Hl).
  revert H; rewrite (red_ax_transport_edges_at_in Hv) Imset.imsetE in_set => /imageP [a Ha Heq].
  enough (Hdone : red_ax_left (Sub v Hv) = a) by by rewrite Hdone.
  symmetry; apply /eqP; rewrite /red_ax_left sub_val_eq /red_ax_left_1 SubK Heq; apply /eqP.
  destruct (other_cut_in_neq Hcut) as [Hc0 Hc1].
  destruct (other_ax_in_neq Hax) as [Ha0 Ha1].
  destruct a as [a Hain].
  rewrite /red_ax_transport SubK.
  destruct a as [a | ].
  - assert (a <> e /\ a <> other_cut Hcut /\ a <> other_ax Hax) as [? [? ?]].
    { splitb;
      intros ?; subst;
      clear - Hain Hc0 Ha0; contradict Hain; apply /negP.
      all: rewrite !in_set; cbn; rewrite ?Hc0 ?Ha0; caseb. }
    case_if.
  - revert Ha; rewrite in_set; cbn; rewrite /red_ax_transport !SubK => /eqP ?; subst v.
    rewrite eq_refl.
    revert Ha1 Hc1 => /eqP Ha1 /eqP Hc1.
    assert (other_ax Hax <> other_cut Hcut).
    { move => Hf {Heq}.
      contradict Hain; apply /negP.
      rewrite !in_set /= Hf Hc0; caseb. }
    assert (source e <> source (other_cut Hcut)).
    { intro Hf.
      destruct (red_ax_degenerate_source Hcut Hax) as [Ho _].
      specialize (Ho Hf). by symmetry in Ho. }
    case_if.
Qed.

Lemma red_ax_p_order (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : proper_order (red_ax_graph_data Hcut Hax).
Proof.
  unfold proper_order, red_ax_graph_data, red_ax_order; cbn.
  split.
  - intros [? ?]; cbn.
    rewrite in_seq_sig SubK -(proj2_sig (all_sigP _)).
    apply p_order.
  - rewrite uniq_seq_sig -(proj2_sig (all_sigP _)).
    apply p_order.
Qed.

Definition red_ax_geos (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : geos := {|
  graph_data_of := red_ax_graph_data Hcut Hax;
  p_deg := @red_ax_p_deg _ _ _ _;
  p_left := @red_ax_p_left _ _ _ _;
  p_order := @red_ax_p_order _ _ _ _;
  |}.

Lemma red_ax_transport_right (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) (v : G)
  (Hv : v \in [set: red_ax_graph_1 Hcut Hax] :\ (source e) :\ (target e)) :
  vlabel v = ⊗ \/ vlabel v = ⅋ ->
  red_ax_transport_in (Sub v Hv) (right (Sub v Hv : red_ax_geos Hcut Hax)) = right v.
Proof.
  intro Hl.
  set w := Sub v Hv : red_ax_geos Hcut Hax.
  apply right_eq; trivial.
  assert (Hdone : red_ax_transport_in w (right w) \in edges_at_in (v : G)).
  { rewrite (red_ax_transport_edges_at_in Hv).
    by apply imset_f, (p_right (v := w)). }
  revert Hdone; rewrite in_set => /eqP Hdone. splitb.
  rewrite -(red_ax_transport_left Hv) //.
  intro Hf.
  assert (Hl' : vlabel w = ⊗ \/ vlabel w = ⅋) by cbnb.
  assert (Hle := p_left Hl').
  destruct (p_right Hl') as [Hr Hc].
  contradict Hc; apply /negP/negPn/eqP.
  by apply (red_ax_transport_inj Hr Hle).
Qed.

Lemma red_ax_transport_ccl (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) (v : G)
  (Hv : v \in [set: red_ax_graph_1 Hcut Hax] :\ (source e) :\ (target e)) :
  vlabel v = ⊗ \/ vlabel v = ⅋ ->
  red_ax_transport_out (Sub v Hv) (ccl (Sub v Hv : red_ax_geos Hcut Hax)) = ccl v.
Proof.
  intro Hl.
  set w := Sub v Hv : red_ax_geos Hcut Hax.
  apply ccl_eq; trivial.
  assert (Hdone : red_ax_transport_out w (ccl w) \in edges_at_out v).
  { rewrite (red_ax_transport_edges_at_out Hv).
    by apply imset_f, (p_ccl (v := w)). }
  by revert Hdone; rewrite in_set => /eqP ?.
Qed.

Lemma red_ax_transport_edge_of_concl (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) (v : G)
  (Hv : v \in [set: red_ax_graph_1 Hcut Hax] :\ (source e) :\ (target e)) :
  vlabel v = c ->
  red_ax_transport_in (Sub v Hv) (edge_of_concl (Sub v Hv : red_ax_geos Hcut Hax)) = edge_of_concl v.
Proof.
  intro Hl.
  set w := Sub v Hv : red_ax_geos Hcut Hax.
  apply concl_eq; trivial.
  assert (Hdone : red_ax_transport_in w (edge_of_concl w) \in edges_at_in v).
  { rewrite (red_ax_transport_edges_at_in Hv).
    by apply imset_f, (p_concl (v := w)). }
  by revert Hdone; rewrite in_set => /eqP Hdone.
Qed.

Lemma red_ax_transport_label (G : proof_structure) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) (b : bool) (v : G)
  (Hv : v \in [set: red_ax_graph_1 Hcut Hax] :\ (source e) :\ (target e)) :
  forall a, elabel a = elabel (red_ax_transport b (Sub v Hv) a).
Proof.
  unfold red_ax_transport.
  intros [[a | ] Ha]; trivial; cbn.
  assert (dual (elabel e) = elabel (other_ax Hax) /\ dual (elabel e) = elabel (other_cut Hcut)) as [? ?].
  { destruct (proper_ax_cut_bis G) as [Hpax Hpcut].
    specialize (Hpax (source e) Hax);
    specialize (Hpcut (target e) Hcut).
    unfold true_on2 in Hpax;
    unfold true_on2 in Hcut.
    specialize (Hpax e (source_in_edges_at_out e));
    specialize (Hpcut e (target_in_edges_at_in e)).
    unfold is_dual_f, is_dual in Hpax;
    unfold is_dual_f, is_dual in Hpcut.
    by revert Hpax Hpcut => /eqP Hpax /eqP Hpcut. }
  by destruct b.
Qed.


Lemma red_ax_p_ax_cut (G : proof_structure) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : proper_ax_cut (red_ax_geos Hcut Hax).
Proof.
  unfold proper_ax_cut.
  intros b [v Hv] Hl; cbn in Hl.
  destruct (p_ax_cut Hl) as [el [er H]].
  revert H; rewrite (red_ax_transport_edges b Hv) => /andP[/andP[Hel Her] /eqP ?].
  revert Hel; rewrite Imset.imsetE in_set => /imageP [El ? ?]; subst el;
  revert Her; rewrite Imset.imsetE in_set => /imageP [Er ? ?]; subst er.
  exists El, Er.
  splitb; apply /eqP.
  by rewrite !(red_ax_transport_label b Hv).
Qed.

Lemma red_ax_p_tens_parr (G : proof_structure) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : proper_tens_parr (red_ax_geos Hcut Hax).
Proof.
  unfold proper_tens_parr.
  intros b [v Hv] Hl; cbn in Hl.
  rewrite (red_ax_transport_label false Hv) 2!(red_ax_transport_label true Hv)
    red_ax_transport_left ?red_ax_transport_right ?red_ax_transport_ccl;
  try (destruct b; by caseb).
  by apply p_tens_parr.
Qed.

Definition red_ax_ps (G : proof_structure) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : proof_structure := {|
  geos_of := red_ax_geos Hcut Hax;
  p_ax_cut := @red_ax_p_ax_cut _ _ _ _;
  p_tens_parr := @red_ax_p_tens_parr _ _ _ _;
  |}.


(** Sequent of an axiom - cut reduction *)
Lemma red_ax_sequent (G : proof_structure) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) :
  sequent (red_ax_ps Hcut Hax) = sequent G.
Proof.
  assert (sequent (red_ax_ps Hcut Hax) = [seq elabel (red_ax_transport_in v (edge_of_concl v)) |
    v <- red_ax_order Hcut Hax]) as ->.
  { apply eq_map; intros [? ?]. apply red_ax_transport_label. }
  transitivity ([seq elabel ((edge_of_concl v)) | v <- [seq val v | v <- red_ax_order Hcut Hax]]).
  { rewrite -map_comp.
    apply (@eq_in_map _); intros [a Ha] Ho.
    rewrite !red_ax_transport_edge_of_concl ?SubK //.
    by assert (vlabel (Sub a Ha : red_ax_graph Hcut Hax) = c)
      by by apply (p_order (red_ax_geos Hcut Hax)). }
  by rewrite -(proj2_sig (all_sigP _)).
Qed.

(** Decreasing number of vertices *)
Lemma red_ax_nb (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) :
  #|red_ax_graph Hcut Hax| = #|G| - 2.
Proof.
  rewrite -(card_imset (f := val)); [ | apply val_inj].
  assert (#|setT :\ (source e) :\ (target e)| = #|G| - 2) as <-.
  { rewrite -cardsT [in RHS](cardsD1 (source e)) [in RHS](cardsD1 (target e)) !in_set.
    assert (target e != source e).
    { apply /negP => /eqP Hf. contradict Hcut. by rewrite Hf Hax. }
    lia. }
  apply eq_card; intro v.
  rewrite Imset.imsetE in_set.
  destruct (v \in [set: G] :\ source e :\ target e) eqn:Hv.
  - apply /imageP.
    by exists (Sub v Hv).
  - apply /imageP; intros [[u U] _ ?]; subst v.
    by rewrite U in Hv.
Qed.


(** Correctness *)
Definition red_ax_G (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut) (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :=
  @invert_edge_graph_left _
  (@extend_edge_graph_left _
    (@extend_edge_graph_left _ (red_ax_graph_left Hcut Hax) (Sub None N) cut (dual (elabel e)) (elabel e))
    (Some (Sub None N)) ax (elabel e) (dual (elabel e)))
  None.

Definition red_ax_iso_v_bij_fwd (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :
  red_ax_G N -> G :=
  fun v => match v with
  | Some (Some (exist u _)) => u
  | Some None               => target e
  | None                    => source e
  end.

Definition red_ax_iso_v_bij_bwd (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :
  G -> red_ax_G N :=
  fun v => if @boolP _ is AltTrue p then Some (Some (Sub v p))
    else if v == source e then None else Some None.

Lemma red_ax_iso_v_bijK (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :
  cancel (@red_ax_iso_v_bij_fwd _ _ _ _ N) (red_ax_iso_v_bij_bwd N).
Proof.
  intros [[[v V] | ] | ]; cbn;
  unfold red_ax_iso_v_bij_bwd; case: {-}_ /boolP => [Hc | /negP ?] //.
  - cbnb.
  - contradict Hc; apply /negP.
    rewrite !in_set. caseb.
  - case: ifP; trivial.
    clear - Hcut Hax => /eqP H.
    contradict Hcut. by rewrite H Hax.
  - contradict Hc; apply /negP.
    rewrite !in_set. caseb.
  - case_if.
Qed.

Lemma red_ax_iso_v_bijK' (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :
  cancel (red_ax_iso_v_bij_bwd N) (@red_ax_iso_v_bij_fwd _ _ _ _ N).
Proof.
  intro v; unfold red_ax_iso_v_bij_bwd.
  case: {-}_ /boolP => [// | ].
  rewrite !in_set => /nandP[/negPn /eqP ? | /nandP[/negPn /eqP ? | //]]; subst; case_if.
Qed.

Definition red_ax_iso_v (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) := {|
  bij_fwd := @red_ax_iso_v_bij_fwd _ _ _ _ N;
  bij_bwd:= red_ax_iso_v_bij_bwd N;
  bijK:= @red_ax_iso_v_bijK _ _ _ _ _;
  bijK':= red_ax_iso_v_bijK' _;
  |}.

Definition red_ax_iso_e_bij_fwd (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :
  edge (red_ax_G N) -> edge G :=
  fun a => match a with
  | None                            => e
  | Some None                       => other_cut Hcut
  | Some (Some (exist None _))      => other_ax Hax
  | Some (Some (exist (Some a) _))  => a
  end.

Definition red_ax_iso_e_bij_bwd (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :
  edge G -> edge (red_ax_G N) :=
  fun a => if @boolP _ is AltTrue p then Some (Some (Sub (Some a) p))
    else if a == e then None
      else if a == other_ax Hax then Some (Some (Sub None N))
        else Some None.

Lemma red_ax_iso_e_bijK (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :
  cancel (@red_ax_iso_e_bij_fwd _ _ _ _ N) (@red_ax_iso_e_bij_bwd _ _ _ _ N).
Proof.
  intros [[[[a | ] A] | ] | ]; cbn;
  unfold red_ax_iso_e_bij_bwd; case: {-}_ /boolP => [Hc | /negP ?] //.
  - cbnb.
  - contradict Hc; apply /negP.
    rewrite !in_set /=; destruct (other_ax_in_neq Hax) as [-> _]. caseb.
  - assert (other_ax Hax == e = false) as -> by (apply /negP/negP; apply (other_ax_in_neq Hax)).
    case_if. cbnb.
  - contradict Hc; apply /negP.
    rewrite !in_set; cbn; destruct (other_cut_in_neq Hcut) as [-> _]. caseb.
  - assert (other_cut Hcut == e = false) as -> by (apply /negP/negP; apply (other_cut_in_neq Hcut)).
    enough (other_cut Hcut == other_ax Hax = false) as -> by trivial.
    apply /eqP => Hc. apply red_ax_degenerate_None in Hc. by contradict Hc; apply /negP/negPn.
  - contradict Hc; apply /negP.
    rewrite !in_set. caseb.
  - case_if.
Qed.

Lemma red_ax_iso_e_bijK' (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :
  cancel (@red_ax_iso_e_bij_bwd _ _ _ _ N) (@red_ax_iso_e_bij_fwd _ _ _ _ N).
Proof.
  intro a.
  unfold red_ax_iso_e_bij_bwd. case: {-}_ /boolP => [Hc | Ha].
  - cbnb.
  - case_if.
    revert Ha; rewrite !in_set /= => /nandP[/nandP[/negPn/eqP Ha | /nandP[/negPn/eqP Ha | //]]
                                          | /nandP[/negPn/eqP Ha | /nandP[/negPn/eqP Ha | //]]].
    + enough (Hf : a \in set0) by (contradict Hf; by rewrite in_set).
      assert (Hc := p_deg_out (target e)).
      rewrite Hcut /= in Hc.
      by rewrite -(cards0_eq Hc) in_set Ha.
    + enough (a = other_ax Hax) by by [].
      by apply other_ax_eq.
    + symmetry; by apply other_cut_eq.
    + enough (Hf : a \in set0) by (contradict Hf; by rewrite in_set).
      assert (Hc := p_deg_in (source e)).
      rewrite Hax /= in Hc.
      by rewrite -(cards0_eq Hc) in_set Ha.
Qed.

Definition red_ax_iso_e (G : geos) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) := {|
  bij_fwd := @red_ax_iso_e_bij_fwd _ _ _ _ N;
  bij_bwd:= @red_ax_iso_e_bij_bwd _ _ _ _ _;
  bijK:= @red_ax_iso_e_bijK _ _ _ _ _;
  bijK':= red_ax_iso_e_bijK' _;
  |}.

Lemma red_ax_iso_ihom (G : proof_structure) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :
  is_ihom (red_ax_iso_v N) (red_ax_iso_e N) pred0.
Proof.
  split.
  - intros [[[[? | ] ?] | ] | ] []; cbnb.
    + by destruct (other_ax_in_neq Hax) as [-> _].
    + by destruct (other_cut_in_neq Hcut) as [-> _].
  - by intros [[[? ?] | ] | ].
  - move => [[[[? | ] ?] | ] | ]; cbnb.
    + destruct (proper_ax_cut_bis G) as [Hpax _].
      specialize (Hpax _ Hax _ (source_in_edges_at_out e)).
      by revert Hpax => /eqP Hpax.
    + destruct (proper_ax_cut_bis G) as [_ Hpcut].
      specialize (Hpcut _ Hcut _ (target_in_edges_at_in e)).
      by revert Hpcut => /eqP Hpcut.
Qed.

Definition red_ax_iso (G : proof_structure) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) := {|
  iso_v := red_ax_iso_v N;
  iso_e := red_ax_iso_e _;
  iso_d := pred0;
  iso_ihom := red_ax_iso_ihom _ |}.

Lemma red_ax_isol (G : proof_structure) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax)
  (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))) :
   red_ax_G N ≃l G.
Proof.
  exists (red_ax_iso N).
  intros [[[v V] | ] | ] Hl; try by destruct Hl.
  unfold red_ax_iso_v_bij_bwd; cbnb; unfold red_ax_left_1; cbn in *.
  assert (left v <> e).
  { intros ?; subst e.
    clear - Hcut Hl; contradict Hcut.
    rewrite left_e; caseb; by destruct Hl as [-> | ->]. }
  assert (left v <> other_cut Hcut).
  { intro Hc.
    clear - Hcut Hl Hc. enough (vlabel (target e) <> cut) by by [].
    destruct (other_cut_in_neq Hcut) as [<- _].
    rewrite -Hc left_e; caseb; by destruct Hl as [-> | ->]. }
    case_if.
    contradict N; apply /negP.
    by apply red_ax_degenerate_None, red_ax_degenerate_source.
Qed.

Lemma red_ax_correct (G : proof_structure) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) :
  correct G -> correct (red_ax_graph_left Hcut Hax).
Proof.
  intro C.
  enough (N : None \in (edge_set ([set: red_ax_graph_1 Hcut Hax] :\ source e :\ target e))).
  { assert (C' := iso_correct (red_ax_isol N) C).
    by apply invert_edge_correct, extend_edge_correct, extend_edge_correct in C'. }
  apply /negPn /negP => N.
  apply red_ax_degenerate_None in N.
  destruct C as [A _].
  unfold uacyclic in A.
  enough (exists (p :  Supath switching (source e) (source e)),
    p <> supath_nil switching (source e)) as [p ?] by by specialize (A _ p).
  enough (P : supath switching (source e) (source e) (forward e :: backward (other_cut Hcut) :: nil))
    by by exists {| upval := _ ; upvalK := P |}.
  rewrite /supath /= in_cons in_nil orb_false_r {2}N.
  destruct (other_cut_in_neq Hcut) as [-> _].
  destruct (other_ax_in_neq Hax) as [-> _].
  splitb.
  cbn. destruct (other_cut_in_neq Hcut) as [-> ?]. rewrite !Hcut /=.
  by apply /eqP; apply nesym; apply /eqP.
Qed.

Definition red_ax_pn (G : proof_net) (e : edge G) (Hcut : vlabel (target e) = cut)
  (Hax : vlabel (source e) = ax) : proof_net := {|
  ps_of := red_ax_ps Hcut Hax;
  p_correct := @red_ax_correct _ _ _ _ (p_correct G);
  |}.



(** * Tensor - cut reduction *)
Definition red_tens_graph_1 (G : base_graph) (v : G) (et ep : edge G) : base_graph :=
  induced (setT :\ source et :\ source ep :\ v).

Lemma red_tens_ineq_in (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  (forall a, source a != v) /\
  source (left (source et)) != source et /\
  source (right (source et)) != source et /\
  source (left (source ep)) != source ep /\
  source (right (source ep)) != source ep /\
  source (left (source et)) != source ep /\
  source (right (source et)) != source ep /\
  source (left (source ep)) != source et /\
  source (right (source ep)) != source et.
Proof.
  assert (forall a, source a != v).
  { intro a; apply /eqP => Ha.
    assert (Hf := p_deg_out v).
    rewrite Hcut in Hf; cbn in Hf.
    assert (Hdone : a \in set0) by by rewrite -(cards0_eq Hf) in_set Ha.
    contradict Hdone; by rewrite in_set. }
  assert (source (left (source et)) != source ep /\ source (right (source et)) != source ep /\
    source (left (source ep)) != source et /\ source (right (source ep)) != source et /\
    source (left (source et)) != source et /\ source (right (source et)) != source et /\
    source (left (source ep)) != source ep /\ source (right (source ep)) != source ep)
    as [? [? [? [? [? [? [? ?]]]]]]].
  { splitb; apply /eqP => Hc;
    [set a := et | set a := et | set a := ep | set a := ep | set a := et | set a := et | set a := ep | set a := ep];
    [set b := ep | set b := ep | set b := et | set b := et | set b := et | set b := et | set b := ep | set b := ep];
    [set f := left (g := G) | set f :=  right (G := G) | set f := left (g := G) | set f := right (G := G)
    | set f := left (g := G) | set f :=  right (G := G) | set f := left (g := G) | set f := right (G := G)].
    all: assert (f (source a) = ccl (source b) /\ b = ccl (source b)) as [Hc0 Hc1] by (split; apply ccl_eq; caseb).
    all: assert (Hc2 : source a = v) by
      (replace v with (target b); rewrite Hc1 -Hc0 ?left_e ?right_e; caseb).
    all: contradict Hcut; by rewrite -Hc2 ?Htens ?Hparr. }
  splitb.
Qed.

Lemma red_tens_in (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  source (left (source et)) \in [set: G] :\ (source et) :\ (source ep) :\ v /\
  source (right (source et)) \in [set: G] :\ (source et) :\ (source ep) :\ v /\
  source (left (source ep)) \in [set: G] :\ (source et) :\ (source ep) :\ v /\
  source (right (source ep)) \in [set: G] :\ (source et) :\ (source ep) :\ v.
Proof.
  destruct (red_tens_ineq_in Hcut Het Hep Htens Hparr) as [? [? [? [? [? [? [? [? ?]]]]]]]].
  rewrite !in_set. splitb.
Qed.

Lemma red_tens_in_slt (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  source (left (source et)) \in setT :\ source et :\ source ep :\ v.
Proof. by destruct (red_tens_in Hcut Het Hep Htens Hparr) as [? [? [? ?]]]. Qed.

Lemma red_tens_in_srt (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  source (right (source et)) \in setT :\ source et :\ source ep :\ v.
Proof. by destruct (red_tens_in Hcut Het Hep Htens Hparr) as [? [? [? ?]]]. Qed.

Lemma red_tens_in_slp (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  source (left (source ep)) \in setT :\ source et :\ source ep :\ v.
Proof. by destruct (red_tens_in Hcut Het Hep Htens Hparr) as [? [? [? ?]]]. Qed.

Lemma red_tens_in_srp (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  source (right (source ep)) \in setT :\ source et :\ source ep :\ v.
Proof. by destruct (red_tens_in Hcut Het Hep Htens Hparr) as [? [? [? ?]]]. Qed.

Definition red_tens_graph (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :=
  (red_tens_graph_1 v et ep) ∔ cut ∔ cut
    ∔ [inl (inl (Sub (source (left (source et))) (red_tens_in_slt Hcut Het Hep Htens Hparr))) ,
        elabel (left (source et)) , inl (inr tt)]
    ∔ [inl (inl (Sub (source (right (source et))) (red_tens_in_srt Hcut Het Hep Htens Hparr))) ,
        elabel (right (source et)) , inr tt]
    ∔ [inl (inl (Sub (source (left (source ep))) (red_tens_in_slp Hcut Het Hep Htens Hparr))) ,
        elabel (left (source ep)) , inr tt]
    ∔ [inl (inl (Sub (source (right (source ep))) (red_tens_in_srp Hcut Het Hep Htens Hparr))) ,
        elabel (right (source ep)) , inl (inr tt)].

Lemma red_tens_cut_set (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  edges_at_in v = [set et; ep].
Proof.
  subst v.
  rewrite other_cut_set.
  replace ep with (other_cut Hcut); trivial.
  symmetry; apply other_cut_eq. splitb.
  intros ?; subst; contradict Hparr.
  by rewrite Htens.
Qed.

Lemma red_tens_ineq_if (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  left (source et) <> right (source et) /\ right (source et) <> left (source et) /\
  left (source ep) <> right (source ep) /\ right (source ep) <> left (source ep) /\
  left (source et) <> left (source ep) /\ left (source ep) <> left (source et) /\
  left (source et) <> right (source ep) /\ right (source ep) <> left (source et) /\
  left (source ep) <> right (source et) /\ right (source et) <> left (source ep) /\
  right (source et) <> right (source ep) /\ right (source ep) <> right (source et).
Proof.
  assert (right (source et) <> left (source et) /\ right (source ep) <> left (source ep)) as [? ?].
  { by elim: (p_right (v := source et)); [ | caseb] => _ /eqP ?;
    elim: (p_right (v := source ep)); [ | caseb] => _ /eqP ?. }
  assert (Hf : source et <> source ep) by (intro Hf; contradict Htens; by rewrite Hf Hparr).
  assert (left (source et) <> left (source ep) /\ left (source et) <> right (source ep) /\
    right (source et) <> left (source ep) /\ right (source et) <> right (source ep)) as [? [? [? ?]]].
  { splitb; intro Hc; contradict Hf.
    - rewrite -(left_e (v := source et)) -1?(left_e (v := source ep)) ?Hc; caseb.
    - rewrite -(left_e (v := source et)) -1?(right_e (v := source ep)) ?Hc; caseb.
    - rewrite -(right_e (v := source et)) -1?(left_e (v := source ep)) ?Hc; caseb.
    - rewrite -(right_e (v := source et)) -1?(right_e (v := source ep)) ?Hc; caseb. }
  assert (left (source et) <> right (source et) /\ left (source ep) <> right (source ep) /\
    left (source ep) <> left (source et) /\ right (source ep) <> left (source et) /\
    left (source ep) <> right (source et) /\ right (source ep) <> right (source et))
    as [? [? [? [? [? ?]]]]] by (splitb; by apply nesym).
  splitb.
Qed.

Definition red_tens_left (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  red_tens_graph Hcut Het Hep Htens Hparr -> edge (red_tens_graph Hcut Het Hep Htens Hparr) :=
  fun u => match u with
  | inl (inl (exist u _)) => if @boolP _ is AltTrue p then
    Some (Some (Some (Some (inl (inl (Sub (left u) p))))))
    else if left u == left (source et) then Some (Some (Some None))
    else if left u == right (source et) then Some (Some None)
    else if left u == left (source ep) then Some None
    else (* left u == right (source ep) *) None
  | _ => None
  end.

Definition red_tens_graph_left (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) : graph_left := {|
  graph_of := red_tens_graph Hcut Het Hep Htens Hparr;
  left := @red_tens_left _ _ _ _ _ _ _ _ _;
  |}.

Lemma red_tens_consistent_order (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  all (pred_of_set (setT :\ source et :\ source ep :\ v)) (order G).
Proof.
  apply /allP => u Hu; cbn.
  assert (Hl : vlabel u = concl_l) by by apply p_order.
  repeat (apply /setD1P; split); trivial; cbn.
  all: apply /eqP => Hc; contradict Hl; by rewrite Hc ?Hcut ?Htens ?Hparr.
Qed.

Definition red_tens_order (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  seq (red_tens_graph Hcut Het Hep Htens Hparr) :=
  [seq inl (inl u) | u <- sval (all_sigP (red_tens_consistent_order Hcut Het Hep Htens Hparr))].

Definition red_tens_graph_data (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) : graph_data := {|
  graph_left_of := red_tens_graph_left Hcut Het Hep Htens Hparr;
  order := red_tens_order _ _ _ _ _;
  |}.

Definition red_tens_transport (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :=
  fun (a : edge (red_tens_graph_data Hcut Het Hep Htens Hparr)) => match a with
  | None => right (source ep)
  | Some None => left (source ep)
  | Some (Some None) => right (source et)
  | Some (Some (Some None)) => left (source et)
  | Some (Some (Some (Some (inl (inl (exist a _)))))) => a
  | Some (Some (Some (Some (inl (inr a))))) => match a with end
  | Some (Some (Some (Some (inr a)))) => match a with end
  end.

Lemma red_tens_transport_inj (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  injective (@red_tens_transport _ _ Hcut _ _ Het Hep Htens Hparr).
Proof.
  unfold red_tens_transport.
  destruct (red_tens_ineq_if Hcut Het Hep Htens Hparr) as [? [? [? [? [? [? [? [? [? [? [? ?]]]]]]]]]]].
  move => [[[[[[[a A] | []] | []] | ] | ] | ] | ] [[[[[[[b B] | []] | []] | ] | ] | ] | ]
    /eqP; cbn => /eqP E; subst; cbnb.
  all: (contradict A || contradict B); apply /negP.
  all: rewrite !in_set ?left_e ?right_e; caseb.
Qed.

Lemma red_tens_transport_edges (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  forall (b : bool) (u : G) (Hu : u \in (setT :\ source et :\ source ep :\ v)),
  edges_at_outin b u =
  [set red_tens_transport a | a in edges_at_outin b (inl (inl (Sub u Hu)) : red_tens_graph_data Hcut Het Hep Htens Hparr)].
Proof.
  intros b u Hu; apply /setP => a.
  rewrite Imset.imsetE !in_set.
  symmetry; apply /imageP; case_if.
  - subst u.
    destruct (red_tens_ineq_in Hcut Het Hep Htens Hparr) as [? [? [? [? [? [? [? [? ?]]]]]]]].
    assert (a <> et /\ a <> ep) as [? ?].
    { split; intros ?; subst; contradict Hu; apply /negP.
      all: rewrite !in_set; cbn.
      all: destruct b; rewrite ?Hep; caseb. }
    destruct (eq_comparable a (left (source et)));
    [ | destruct (eq_comparable a (left (source ep)))];
    [ | | destruct (eq_comparable a (right (source et)))];
    [ | | | destruct (eq_comparable a (right (source ep)))];
    try subst a.
    5:{ assert (Ina : a \in edge_set (setT :\ source et :\ source ep :\ v)).
        { rewrite !in_set; cbn. splitb.
          all: apply /eqP => Hf.
          - assert (a = ccl (source ep) /\ ep = ccl (source ep))
              as [? ?] by (split; apply ccl_eq; caseb).
            by assert (a = ep) by by subst.
          - assert (a = ccl (source et) /\ et = ccl (source et))
              as [? ?] by (split; apply ccl_eq; caseb).
            by assert (a = et) by by subst.
          - assert (Hin : a \in edges_at_in v) by by rewrite in_set Hf.
            by revert Hin; rewrite (red_tens_cut_set Hcut Het Hep Htens Hparr) !in_set => /orP[/eqP ? | /eqP ?].
          - assert (Hin : a \in edges_at_in (source ep)) by by rewrite in_set Hf.
            by revert Hin; rewrite right_set ?in_set; [ | caseb] => /orP[/eqP ? | /eqP ?].
          - assert (Hin : a \in edges_at_in (source et)) by by rewrite in_set Hf.
            by revert Hin; rewrite right_set ?in_set; [ | caseb] => /orP[/eqP ? | /eqP ?]. }
        exists (Some (Some (Some (Some (inl (inl (Sub a Ina))))))); trivial.
        by rewrite !in_set; cbnb. }
    all: destruct b;
      [contradict Hu; apply /negP; rewrite !in_set ?left_e ?right_e; caseb | ].
    4: exists None; trivial.
    3: exists (Some (Some None)); trivial.
    2: exists (Some None); trivial.
    1: exists (Some (Some (Some None))); trivial.
    all: by rewrite !in_set; cbnb.
  - intros [[[[[[[[d ?] | []] | []] | ] | ] | ] | ] Hdin Hdeq].
    all: cbn in Hdeq; subst a.
    all: revert Hdin; rewrite !in_set /=.
    all: destruct b; cbn; rewrite ?SubK // => /eqP ? //.
Qed.

Lemma red_tens_transport_left (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  forall (u : G) (Hu : u \in setT :\ source et :\ source ep :\ v),
  vlabel u = ⊗ \/ vlabel u = ⅋ ->
  red_tens_transport (left (inl (inl (Sub u Hu)) : red_tens_graph_data Hcut Het Hep Htens Hparr)) = left u.
Proof.
  intros u Hu Hl.
  cbn; rewrite /red_tens_transport /red_tens_left.
  destruct (Sub u Hu) as [u' ?] eqn:Hr; revert Hr => /eqP; cbnb => /eqP ?; subst u'.
  case: {-}_ /boolP => [? | Hc] //.
  contradict Hc; apply /negP/negPn.
  revert Hu; rewrite !in_set; cbn => /andP[/eqP Hu /andP[/eqP ? /andP[/eqP ? _]]].
  splitb; apply /eqP; rewrite ?left_e //.
  - intro Ha.
    assert (Hf := p_deg_out v). rewrite Hcut /= in Hf.
    assert (Hdone : left u \in set0) by by rewrite -(cards0_eq Hf) in_set Ha.
    contradict Hdone; by rewrite in_set.
  - intro Ha.
    assert (C : left u = ep).
    { transitivity (ccl (source ep)); [ | symmetry]; apply ccl_eq; caseb. }
    assert (u = target ep) by by rewrite -C left_e; caseb. subst u.
    contradict Hcut.
    by rewrite -Hep; destruct Hl as [-> | ->].
  - intro Ha.
    assert (C : left u = et).
    { transitivity (ccl (source et)); [ | symmetry]; apply ccl_eq; caseb. }
    assert (u = target et) by by rewrite -C left_e; caseb. subst u.
    contradict Hcut.
    by rewrite -Het; destruct Hl as [-> | ->].
Qed.


Lemma red_tens_p_deg (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  proper_degree (red_tens_graph_data Hcut Het Hep Htens Hparr).
Proof.
  unfold proper_degree, red_tens_graph_data.
  intros b [[[u Hu] | []] | []]; cbn.
  - rewrite -(p_deg b u) (red_tens_transport_edges _ _ _ _ _ _ Hu) card_imset //.
    apply red_tens_transport_inj.
  - assert (edges_at_in (inl (inr tt) : red_tens_graph_data Hcut Het Hep Htens Hparr) =
      [set Some (Some (Some None)); None] /\
      edges_at_out (inl (inr tt) : red_tens_graph_data Hcut Het Hep Htens Hparr) = set0) as [Hin Hout].
    { split; apply /setP; move => [[[[[[[? ?] | []] | []] | ] | ] | ] | ]; by rewrite !in_set. }
    destruct b; by rewrite ?Hin ?Hout ?cards2 ?cards0.
  - assert (edges_at_in (inr tt : red_tens_graph_data Hcut Het Hep Htens Hparr) =
      [set Some (Some None); Some None] /\
      edges_at_out (inr tt : red_tens_graph_data Hcut Het Hep Htens Hparr) = set0) as [Hin Hout].
    { split; apply /setP; move => [[[[[[[? ?] | []] | []] | ] | ] | ] | ]; by rewrite !in_set. }
    destruct b; by rewrite ?Hin ?Hout ?cards2 ?cards0.
Qed.

Lemma red_tens_p_left (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  proper_left (red_tens_graph_data Hcut Het Hep Htens Hparr).
Proof.
  unfold proper_left.
  intros [[[u Hu] | []] | []] Hl;
  try (destruct Hl as [Hl | Hl]; by contradict Hl).
  assert (H := p_left Hl).
  revert H; rewrite (red_tens_transport_edges _ _ _ _ _ _ Hu) Imset.imsetE in_set => /imageP [a Ha Heq].
  enough (Hd : left (inl (inl (Sub u Hu)) : red_tens_graph_data Hcut Het Hep Htens Hparr) = a) by by rewrite Hd.
  rewrite -(red_tens_transport_left _ _ _ _ _ Hu Hl) in Heq.
  apply (red_tens_transport_inj Heq).
Qed.

Lemma red_tens_p_order (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  proper_order (red_tens_graph_data Hcut Het Hep Htens Hparr).
Proof.
  unfold proper_order, red_tens_graph_data, red_tens_order; cbn.
  split.
  - intros [[[u ?] | ] | ]; cbn.
    { rewrite mem_map; [ | apply inj_comp; apply inl_inj].
      rewrite in_seq_sig SubK -(proj2_sig (all_sigP _)).
      apply p_order. }
    all: split; move => H //.
    all: contradict H; apply /negP.
    all: remember (sval (all_sigP _)) as l; clear; by induction l.
  - rewrite map_inj_uniq; [ | apply inj_comp; apply inl_inj].
    rewrite uniq_seq_sig -(proj2_sig (all_sigP _)).
    apply p_order.
Qed.

Definition red_tens_geos (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) : geos := {|
  graph_data_of := red_tens_graph_data Hcut Het Hep Htens Hparr;
  p_deg := @red_tens_p_deg _ _ _ _ _ _ _ _ _;
  p_left := @red_tens_p_left _ _ _ _ _ _ _ _ _;
  p_order := @red_tens_p_order _ _ _ _ _ _ _ _ _;
  |}.

Lemma red_tens_transport_right (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  forall (u : G) (Hu : u \in setT :\ source et :\ source ep :\ v),
  vlabel u = ⊗ \/ vlabel u = ⅋ ->
  red_tens_transport (right (inl (inl (Sub u Hu)) : red_tens_geos Hcut Het Hep Htens Hparr)) = right u.
Proof.
  intros u Hu Hl.
  set w : red_tens_geos Hcut Het Hep Htens Hparr := inl (inl (Sub u Hu)).
  apply right_eq; trivial.
  assert (Hdone : red_tens_transport (right w) \in edges_at_in u).
  { rewrite (red_tens_transport_edges _ _ _ _ _ _ Hu).
    by apply imset_f, (p_right (v := w)). }
  revert Hdone; rewrite in_set => /eqP Hdone. splitb.
  rewrite -(red_tens_transport_left _ _ _ _ _ Hu) // -/w.
  intro Hf.
  assert (Hl' : vlabel w = ⊗ \/ vlabel w = ⅋) by by [].
  destruct (p_right Hl') as [_ Hc].
  contradict Hc; apply /negP/negPn/eqP.
  by apply red_tens_transport_inj.
Qed.

Lemma red_tens_transport_ccl (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  forall (u : G) (Hu : u \in setT :\ source et :\ source ep :\ v),
  vlabel u = ⊗ \/ vlabel u = ⅋ ->
  red_tens_transport (ccl (inl (inl (Sub u Hu)) : red_tens_geos Hcut Het Hep Htens Hparr)) = ccl u.
Proof.
  intros u Hu Hl.
  set w : red_tens_geos Hcut Het Hep Htens Hparr := inl (inl (Sub u Hu)).
  apply ccl_eq; trivial.
  assert (Hdone : red_tens_transport (ccl w) \in edges_at_out u).
  { rewrite (red_tens_transport_edges _ _ _ _ _ _ Hu).
    by apply imset_f, (p_ccl (v := w)). }
  by revert Hdone; rewrite in_set => /eqP ?.
Qed.

Lemma red_tens_transport_edge_of_concl (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  forall (u : G) (Hu : u \in setT :\ source et :\ source ep :\ v),
  vlabel u = c ->
  red_tens_transport (edge_of_concl (inl (inl (Sub u Hu)) : red_tens_geos Hcut Het Hep Htens Hparr)) = edge_of_concl u.
Proof.
  intros u Hu Hl.
  set w : red_tens_geos Hcut Het Hep Htens Hparr := inl (inl (Sub u Hu)).
  apply concl_eq; trivial.
  assert (Hdone : red_tens_transport (edge_of_concl w) \in edges_at_in u).
  { rewrite (red_tens_transport_edges _ _ _ _ _ _ Hu).
    by apply imset_f, (p_concl (v := w)). }
  by revert Hdone; rewrite in_set => /eqP Hdone.
Qed.

Lemma red_tens_transport_label (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  forall (a : edge (red_tens_geos Hcut Het Hep Htens Hparr)), elabel a = elabel (red_tens_transport a).
Proof. by intros [[[[[[[? ?] | []] | []] | ] | ] | ] | ]. Qed.


Lemma red_tens_p_ax_cut (G : proof_structure) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  proper_ax_cut (red_tens_geos Hcut Het Hep Htens Hparr).
Proof.
  unfold proper_ax_cut.
  destruct (proper_ax_cut_bis G) as [_ Hpcut].
  assert (Hvet : et \in edges_at_in v) by by rewrite in_set Het.
  specialize (Hpcut _ Hcut _ Hvet).
  unfold is_dual_f, is_dual in Hpcut; revert Hpcut => /eqP Hpcut.
  assert (Ht := p_tens Htens); cbn in Ht.
  assert (Hp := p_parr Hparr); cbn in Hp.
  assert (et = ccl (source et) /\ ep = ccl (source ep)) as [Hct Hcp] by (split; apply ccl_eq; caseb).
  rewrite -Hct in Ht;
  rewrite -Hcp in Hp.
  assert (Hoep : ep = other (pre_proper_cut Hcut) Hvet).
  { apply other_eq.
    - by rewrite in_set Hep.
    - intro Hc; clear - Hc Htens Hparr; contradict Hparr.
      by rewrite Hc Htens. }
  rewrite -Hoep Ht Hp {Hoep Hvet Hct Hcp Ht Hp} in Hpcut; cbn in Hpcut.
  inversion Hpcut as [[H0 H1]]; clear Hpcut.
  intros b [[[u Hu] | []] | []] Hl; cbn in Hl.
  { destruct (p_ax_cut Hl) as [el [er H]].
    revert H; rewrite (red_tens_transport_edges _ _ _ _ _ b Hu) => /andP[/andP[Hel Her] /eqP Heq].
    revert Hel; rewrite Imset.imsetE in_set => /imageP [El ? HeEl]; subst el;
    revert Her; rewrite Imset.imsetE in_set => /imageP [Er ? HeEr]; subst er.
    exists El, Er.
    splitb; apply /eqP.
    by rewrite !red_tens_transport_label. }
  all: destruct b; try by [].
  1: exists (Some (Some (Some None))), None.
  2: exists (Some (Some None)), (Some None).
  all: rewrite !in_set; cbnb; apply /eqP.
  all: by rewrite -?H0 -?H1 bidual.
Qed.

Lemma red_tens_p_tens_parr (G : proof_structure) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  proper_tens_parr (red_tens_geos Hcut Het Hep Htens Hparr).
Proof.
  unfold proper_tens_parr.
  intros b [[[u Hu] | []] | []] Hl; cbn in Hl.
  all: try (destruct b; by contradict Hl).
  rewrite !red_tens_transport_label red_tens_transport_left ?red_tens_transport_right ?red_tens_transport_ccl;
  try (destruct b; by caseb).
  by apply p_tens_parr.
Qed.

Definition red_tens_ps (G : proof_structure) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) : proof_structure := {|
  geos_of := red_tens_geos Hcut Het Hep Htens Hparr;
  p_ax_cut := @red_tens_p_ax_cut _ _ _ _ _ _ _ _ _;
  p_tens_parr := @red_tens_p_tens_parr _ _ _ _ _ _ _ _ _;
  |}.


(** Sequent of an tensor - cut reduction *)
Lemma red_tens_sequent (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  sequent (red_tens_geos Hcut Het Hep Htens Hparr) = sequent G.
Proof.
  transitivity ([seq elabel (@red_tens_transport _ _ Hcut _ _ Het Hep Htens Hparr (edge_of_concl u)) |
    u <- red_tens_order Hcut Het Hep Htens Hparr]).
  { apply eq_map => ?. apply red_tens_transport_label. }
  rewrite /red_tens_order -map_comp.
  transitivity ([seq elabel (edge_of_concl u) | u <-
    [seq val u | u <- sval (all_sigP (red_tens_consistent_order Hcut Het Hep Htens Hparr))]]).
  2:{ by rewrite -(proj2_sig (all_sigP _)). }
  rewrite -map_comp.
  apply (@eq_in_map _); move => [a A].
  rewrite in_seq_sig !SubK -(proj2_sig (all_sigP _)).
  move => In /=.
  rewrite red_tens_transport_edge_of_concl //; by apply p_order.
Qed.


(** Decreasing number of vertices *)
Lemma red_tens_nb (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  #|red_tens_graph Hcut Het Hep Htens Hparr| = #|G| - 1.
Proof.
  assert (source et <> source ep).
  { intro Hc. contradict Htens.
    by rewrite Hc Hparr. }
  set f := fun (u : red_tens_graph Hcut Het Hep Htens Hparr) => match u with
  | inl (inl u) => val u
  | inl (inr _) => source et
  | inr _ => source ep
  end.
  assert (injective f).
  { assert (source ep <> source et) by by apply nesym.
    intros [[[u Hu] | []] | []] [[[u' Hu'] | []] | []]; rewrite /f ?SubK; intro Heq; cbnb.
    all: revert Hu || revert Hu'; rewrite !in_set Heq;
      by move => /andP[/eqP _ /andP[/eqP ? /andP[/eqP ? _]]]. }
  rewrite -(card_imset (f := f)) //.
  assert (#|setT :\ v| = #|G| - 1) as <-.
  { rewrite -cardsT [in RHS](cardsD1 v) in_set. lia. }
  apply eq_card; intro u.
  rewrite Imset.imsetE !in_set andb_true_r.
  destruct (eq_comparable u v) as [ | Hneq].
  - subst; rewrite eq_refl; cbn.
    apply /imageP; intros [[[[u Hin] | []] | []] _ Huv]; rewrite /f ?SubK in Huv.
    + revert Hin; rewrite !in_set; cbn => /andP[/eqP ? /andP[/eqP ? /andP[/eqP ? _]]].
      by subst.
    + clear - Htens Huv Hcut; contradict Htens.
      by rewrite -Huv Hcut.
    + clear - Hparr Huv Hcut; contradict Hparr.
      by rewrite -Huv Hcut.
  - transitivity true.
    2:{ symmetry; by apply /negP /negP /eqP. }
    apply /imageP.
    destruct (eq_comparable u (source et));
    [ | destruct (eq_comparable u (source ep))].
    + by exists (inl (inr tt)).
    + by exists (inr tt).
    + assert (Hin : u \in setT :\ source et :\ source ep :\ v) by
        (rewrite !in_set; cbn; splitb; by apply /eqP).
      by exists (inl (inl (Sub u Hin))).
Qed.


(** Correctness *)
Lemma red_tens_ineq_switching (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  switching et <> switching ep /\
  switching (left (source et)) <> switching (right (source et)) /\
  switching (left (source et)) <> switching et /\
  switching (left (source et)) <> switching ep /\
  switching (left (source et)) <> switching (left (source ep)) /\
  switching (left (source et)) <> switching (right (source ep)) /\
  switching (right (source et)) <> switching et /\
  switching (right (source et)) <> switching ep /\
  switching (right (source et)) <> switching (left (source ep)) /\
  switching (right (source et)) <> switching (right (source ep)) /\
  switching et <> switching (left (source ep)) /\
  switching ep <> switching (left (source ep)) /\
  switching et <> switching (right (source ep)) /\
  switching ep <> switching (right (source ep)).
Proof.
  split.
  { cbnb. rewrite Het Hep Hcut /=. intro Hs.
    enough (vlabel (source et) <> ⊗) by by [].
    by rewrite Hs Hparr. }
  split.
  { cbnb. rewrite left_e ?right_e !Htens /=; caseb.
    apply nesym; apply /eqP; apply p_right; caseb. }
  splitb => Hs.
  all: apply switching_eq in Hs.
  all: rewrite ?left_e ?right_e in Hs; caseb.
  all: enough (vlabel v <> cut) by by [].
  all: try (rewrite -Het Hs).
  all: try (rewrite -Het -Hs).
  all: try (rewrite -Hep Hs).
  all: try (rewrite -Hep -Hs).
  all: try rewrite ?Htens ?Hparr //.
  all: enough (vlabel (source et) <> ⊗) by by [].
  all: by rewrite Hs ?Het ?Hep ?Hcut ?Hparr.
Qed.

Lemma red_tens_target_in (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  forall a f, target a = target f -> a \in edge_set (setT :\ source et :\ source ep :\ v) ->
  f \in edge_set (setT :\ source et :\ source ep :\ v).
Proof.
  move => a f T.
  rewrite !in_set; introb; splitb; apply /eqP => Hc.
  all: try by rewrite_all Hc.
  - enough (Hf : f \in set0) by (contradict Hf; by rewrite in_set).
    assert (Hv := p_deg_out v).
    rewrite Hcut /= in Hv.
    by rewrite -(cards0_eq Hv) in_set Hc.
  - assert (f = ep).
    { transitivity (ccl (source ep)); [ | symmetry]; apply ccl_eq; caseb. }
    subst f.
    by rewrite_all Hep.
  - assert (f = et).
    { transitivity (ccl (source et)); [ | symmetry]; apply ccl_eq; caseb. }
    subst f.
    by rewrite_all Het.
Qed.

Lemma red_tens_switching (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  forall a f A F,
  switching a = switching f ->
  switching (Some (Some (Some (Some (inl (inl (Sub a A)))))) : edge (red_tens_graph_left Hcut Het Hep Htens Hparr)) =
  switching (Some (Some (Some (Some (inl (inl (Sub f F)))))) : edge (red_tens_graph_left Hcut Het Hep Htens Hparr)).
Proof.
  move => a f A F S.
  assert (T : target a = target f) by by apply switching_eq.
  revert S => /eqP.
  unfold switching; case_if.
  all: (assert (Hf : vlabel (target f) = ⅋) by (by apply /eqP))
     || assert (Hf : vlabel (target f) <> ⅋) by (by apply /eqP);
       (assert (Ha : vlabel (target a) = ⅋) by (by apply /eqP))
     || assert (Ha : vlabel (target a) <> ⅋) by (by apply /eqP).
  all: try by rewrite ->T in *; try by cbnb.
  destruct (Sub (target ((@sval) _ _ (Sub a A))) (induced_proof true (valP (Sub a A)))) as [y ?] eqn:Y.
  assert (y = target a) as -> by by revert Y => /eqP; cbnb => /eqP ->.
  destruct (Sub (target ((@sval) _ _ (Sub f F))) (induced_proof true (valP (Sub f F)))) as [z ?] eqn:Z.
  assert (z = target f) as -> by by revert Z => /eqP; cbnb => /eqP ->.
  by rewrite T.
Qed.

Fixpoint red_tens_upath_bwd (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) (p : @upath _ _ (red_tens_graph_left Hcut Het Hep Htens Hparr))
  {struct p} : @upath _ _ G :=
  match p with
  | [::] => [::]
  | a :: p => (red_tens_transport a.1, a.2) :: red_tens_upath_bwd p
  end.

Lemma red_tens_upath_bwd_in (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  forall (p : @upath _ _ (red_tens_graph_left Hcut Het Hep Htens Hparr)) a A b,
  [forall b, (None, b) \notin p] -> [forall b, (Some None, b) \notin p] ->
  [forall b, (Some (Some None), b) \notin p] -> [forall b, (Some (Some (Some None)), b) \notin p] ->
  (a, b) \in red_tens_upath_bwd p ->
  (Some (Some (Some (Some (inl (inl (Sub a A)))))), b) \in p.
Proof.
  move => p; induction p as [ | f p IH] => // a A b N SN SSN SSSN.
  destruct f as ([[[[[[[f F] | []] | []] | ] | ] | ] | ], c);
  [ | by revert SSSN => /forallP /(_ c); rewrite in_cons => /norP [/eqP ? _]
    | by revert SSN => /forallP /(_ c); rewrite in_cons => /norP [/eqP ? _]
    | by revert SN => /forallP /(_ c); rewrite in_cons => /norP [/eqP ? _]
    | by revert N => /forallP /(_ c); rewrite in_cons => /norP [/eqP ? _]].
  rewrite !in_cons; cbnb.
  introb.
  { subst. apply /orP; left. splitb; by apply /eqP. }
  apply /orP; right.
  apply IH; try apply /forallP => d;
  [revert N |revert SN |revert SSN |revert SSSN | assumption].
  all: by move => /forallP /(_ d); rewrite in_cons => /norP [_ ->].
Qed.

Lemma red_tens_upath_Some (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋)
  (p : @upath _ _ (red_tens_geos Hcut Het Hep Htens Hparr)) :
  forall (u w : red_tens_geos Hcut Het Hep Htens Hparr),
  p <> nil -> supath switching u w p ->
  [forall b, (None, b) \notin p] -> [forall b, (Some None, b) \notin p] ->
  [forall b, (Some (Some None), b) \notin p] -> [forall b, (Some (Some (Some None)), b) \notin p] ->
  exists u' U' w' W', u = inl (inl (Sub u' U')) /\ w = inl (inl (Sub w' W')) /\
  supath switching u' w' (red_tens_upath_bwd p).
Proof.
  induction p as [ | a p IH] => // u w _ P N SN SSN SSSN.
  assert ([forall b, (None, b) \notin p] /\ [forall b, (Some None, b) \notin p] /\
    [forall b, (Some (Some None), b) \notin p] /\ [forall b, (Some (Some (Some None)), b) \notin p])
    as [N' [SN' [SSN' SSSN']]].
  { splitb; apply /forallP => b;
    [revert N | revert SN | revert SSN | revert SSSN].
    all: move  => /forallP /(_ b); by rewrite in_cons => /norP[_ ?]. }
  destruct a as ([[[[[[[a A] | []] | []] | ] | ] | ] | ], b);
  [ | by revert SSSN => /forallP /(_ b); rewrite in_cons => /norP [/eqP ? _]
    | by revert SSN => /forallP /(_ b); rewrite in_cons => /norP [/eqP ? _]
    | by revert SN => /forallP /(_ b); rewrite in_cons => /norP [/eqP ? _]
    | by revert N => /forallP /(_ b); rewrite in_cons => /norP [/eqP ? _]].
  clear SSSN SSN SN N.
  revert P; unfold supath at 1; cbn; rewrite in_cons
    => /andP[/andP[/andP[/eqP ? W] /andP[U0 U1]] /norP[_ N]]; subst u.
  assert (P : supath switching (inl (inl (Sub (endpoint b a) (induced_proof b (valP (exist _ a A))))) :
    red_tens_geos Hcut Het Hep Htens Hparr) w p) by splitb.
  destruct p as [ | f p].
  { exists (endpoint (~~ b) a), (induced_proof (~~ b) (valP (exist _ a A))),
      (endpoint b a), (induced_proof b (valP (exist _ a A))).
    revert W; cbn => /eqP ?; subst w.
    splitb. }
  assert (Hr : f :: p <> [::]) by by [].
  destruct (IH _ _ Hr P N' SN' SSN' SSSN') as [x [X [y [Y [Hx [Hy P']]]]]].
  clear Hr IH.
  revert Hx => /eqP Hx; cbn in Hx; rewrite !SubK in Hx; revert Hx => /eqP ?. subst w x.
  exists (endpoint (~~ b) a), (induced_proof (~~ b) (valP (exist _ a A))), y, Y.
  revert P'.
  remember (f :: p) as p'.
  unfold supath; cbn => /andP[/andP[W' U'] N''].
  splitb.
  revert U0; apply contra => /mapP [[d db] In Seq]; apply /mapP.
  set D := (red_tens_target_in Hcut Het Hep Htens Hparr (switching_eq Seq) A).
  exists (Some (Some (Some (Some (inl (inl (Sub d D)))))), db).
  - by apply red_tens_upath_bwd_in.
  - by apply red_tens_switching.
Qed.

Lemma red_tens_uacyclic_nocut (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  uacyclic (switching (G := G)) ->
  forall (p : @upath _ _ (red_tens_geos Hcut Het Hep Htens Hparr)),
  forall (u : red_tens_geos Hcut Het Hep Htens Hparr),
  supath switching u u p ->
  [forall b, (None, b) \notin p] -> [forall b, (Some None, b) \notin p] ->
  [forall b, (Some (Some None), b) \notin p] -> [forall b, (Some (Some (Some None)), b) \notin p] ->
  p = [::].
Proof.
  move => A p u P N SN SSN SSSN.
  destruct p as [ | a p]; trivial.
  assert (NN : a :: p <> [::]) by by [].
  destruct (red_tens_upath_Some NN P N SN SSN SSSN) as [? [? [u' [? [? [Hu'' P']]]]]]. subst u.
  revert Hu'' => /eqP; cbnb => /eqP ?. subst u'.
  specialize (A _ {| upval := _ ; upvalK := P' |}).
  contradict A; cbnb.
Qed.

Lemma red_tens_upath_fN (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  forall p u U w W,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub w W))) p ->
  (forward None \in p -> exists l r, p = l ++ forward None :: backward (Some (Some (Some None))) :: r) /\
  (forward (Some None) \in p -> exists l r, p = l ++ forward (Some None) :: backward (Some (Some None)) :: r) /\
  (forward (Some (Some None)) \in p -> exists l r, p = l ++ forward (Some (Some None)) :: backward (Some None) :: r) /\
  (forward (Some (Some (Some None))) \in p -> exists l r, p = l ++ forward (Some (Some (Some None))) :: backward None :: r).
Proof.
  move => p u U w W P; splitb => In.
  all: destruct (in_elt_sub In) as [l [r ?]]; subst p.
  all: exists l, (behead r); f_equal; f_equal.
  all: destruct (supath_subKK P) as [_ R]; clear - R.
  all: revert R; rewrite /supath /= in_cons => /andP[/andP[/andP[_ ?] /andP[? _]] _].
  all: by destruct r as [ | ([[[[[[[? ?] | []] | []] | ] | ] | ] | ], []) ?].
Qed.

Lemma red_tens_upath_bN (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  forall p u U w W,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub w W))) p ->
  (backward None \in p -> exists l r, p = l ++ forward (Some (Some (Some None))) :: backward None :: r) /\
  (backward (Some None) \in p -> exists l r, p = l ++ forward (Some (Some None)) :: backward (Some None) :: r) /\
  (backward (Some (Some None)) \in p -> exists l r, p = l ++ forward (Some None) :: backward (Some (Some None)) :: r) /\
  (backward (Some (Some (Some None))) \in p -> exists l r, p = l ++ forward None :: backward (Some (Some (Some None))) :: r).
Proof.
  move => p u U w W P.
  destruct (red_tens_upath_fN (supath_revK P)) as [N [SN [SSN SSSN]]].
  splitb => In; [set H := N | set H := SN | set H := SSN | set H := SSSN].
  1: assert (In' : forward None \in upath_rev p) by by rewrite (upath_rev_in p).
  2: assert (In' : forward (Some None) \in upath_rev p) by by rewrite (upath_rev_in p).
  3: assert (In' : forward (Some (Some None)) \in upath_rev p) by by rewrite (upath_rev_in p).
  4: assert (In' : forward (Some (Some (Some None))) \in upath_rev p) by by rewrite (upath_rev_in p).
  all: destruct (H In') as [l [r Hp]].
  all: exists (upath_rev (r : @upath _ _ (red_tens_geos Hcut Het Hep Htens Hparr))),
         (upath_rev (l : @upath _ _ (red_tens_geos Hcut Het Hep Htens Hparr))).
  all: by rewrite -(upath_rev_inv p) Hp upath_rev_cat /= -!cats1 -!catA.
Qed.

Lemma red_tens_NSSSN (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  forall p u U w W,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub w W))) p ->
  [forall b, (None, b) \notin p] -> [forall b, (Some (Some (Some None)), b) \notin p].
Proof.
  intros p u U w W P.
  enough (Hd : forall b, (Some (Some (Some None)), b) \in p -> (None, ~~b) \in p).
  { move => /forallP H; apply /forallP => b; revert H => /(_ (~~b)). apply contra, Hd. }
  move => [] In.
  - destruct (red_tens_upath_fN P) as [_ [_ [_ H]]]. specialize (H In).
    destruct H as [l [r ?]]; subst p; clear.
    rewrite mem_cat !in_cons. caseb.
  - destruct (red_tens_upath_bN P) as [_ [_ [_ H]]]. specialize (H In).
    destruct H as [l [r ?]]; subst p; clear.
    rewrite mem_cat !in_cons. caseb.
Qed.

Lemma red_tens_SNSSN (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  forall p u U w W,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub w W))) p ->
  [forall b, (Some None, b) \notin p] -> [forall b, (Some (Some None), b) \notin p].
Proof.
  intros p u U w W P.
  enough (Hd : forall b, (Some (Some None), b) \in p -> (Some None, ~~b) \in p).
  { move => /forallP H; apply /forallP => b; revert H => /(_ (~~b)). apply contra, Hd. }
  move => [] In.
  - destruct (red_tens_upath_fN P) as [_ [_ [H _]]]. specialize (H In).
    destruct H as [l [r ?]]; subst p; clear.
    rewrite mem_cat !in_cons. caseb.
  - destruct (red_tens_upath_bN P) as [_ [_ [H _]]]. specialize (H In).
    destruct H as [l [r ?]]; subst p; clear.
    rewrite mem_cat !in_cons. caseb.
Qed.

Lemma red_tens_upath_bwd_nin (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  forall (p : @upath _ _ (red_tens_graph_left Hcut Het Hep Htens Hparr)) b,
  [forall b, (None, b) \notin p] -> [forall b, (Some None, b) \notin p] ->
  [forall b, (Some (Some None), b) \notin p] -> [forall b, (Some (Some (Some None)), b) \notin p] ->
  (left (source et), b) \notin red_tens_upath_bwd p /\
  (right (source et), b) \notin red_tens_upath_bwd p /\
  (left (source ep), b) \notin red_tens_upath_bwd p /\
  (right (source ep), b) \notin red_tens_upath_bwd p /\
  (et, b) \notin red_tens_upath_bwd p /\
  (ep, b) \notin red_tens_upath_bwd p.
Proof.
  move => p b. induction p as [ | a p IH]; move => // N SN SSN SSSN /=.
  rewrite !in_cons; cbn. repeat (split).
  all: apply /norP; split; [ |
    apply IH; apply /forallP => c;
    [revert N | revert SN | revert SSN | revert SSSN];
    move => /forallP /(_ c);
    rewrite !in_cons; introb].
  all: destruct a as ([[[[[[[a A] | []] | []] | ] | ] | ] | ], c);
  [ | by revert SSSN => /forallP /(_ c); rewrite in_cons => /norP [/eqP ? _]
    | by revert SSN => /forallP /(_ c); rewrite in_cons => /norP [/eqP ? _]
    | by revert SN => /forallP /(_ c); rewrite in_cons => /norP [/eqP ? _]
    | by revert N => /forallP /(_ c); rewrite in_cons => /norP [/eqP ? _]].
  all: cbn; apply /nandP; left; apply /eqP => ?; subst a.
  all: clear - A Htens Hparr; contradict A; apply /negP.
  all: rewrite !in_set ?left_e ?right_e; caseb.
Qed. (* TODO mettre ça ailleurs, et plus généralement organiser cette partie lorsque acyc finie *)

Lemma red_tens_upath_bwd_nin_switching (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  forall (p : @upath _ _ (red_tens_graph_left Hcut Het Hep Htens Hparr)),
  [forall b, (None, b) \notin p] -> [forall b, (Some None, b) \notin p] ->
  [forall b, (Some (Some None), b) \notin p] -> [forall b, (Some (Some (Some None)), b) \notin p] ->
  switching (left (source et)) \notin [seq switching a.1 | a <- red_tens_upath_bwd p] /\
  switching (right (source et)) \notin [seq switching a.1 | a <- red_tens_upath_bwd p] /\
  switching (left (source ep)) \notin [seq switching a.1 | a <- red_tens_upath_bwd p] /\
  switching (right (source ep)) \notin [seq switching a.1 | a <- red_tens_upath_bwd p] /\
  switching et \notin [seq switching a.1 | a <- red_tens_upath_bwd p] /\
  switching ep \notin [seq switching a.1 | a <- red_tens_upath_bwd p].
Proof.
  move => p N SN SSN SSSN.
  splitb.
  all: apply /mapP; move => [[a b] In S].
  all: apply switching_eq in S; rewrite ?left_e ?right_e /= in S; caseb.
  all: destruct (red_tens_upath_bwd_nin b N SN SSN SSSN) as [? [? [? [? [? ?]]]]].
  all: assert (Hc := target_in_edges_at_in a).
  all: rewrite -S in Hc;
    (rewrite Het in Hc || rewrite Hep in Hc || rewrite right_set ?in_set in Hc; caseb).
  all: try (revert Hc => /orP[/eqP ? | /eqP ?]; subst a; by contradict In; apply /negP).
  all: rewrite (red_tens_cut_set Hcut Het Hep Htens Hparr) !in_set in Hc.
  all: revert Hc => /orP[/eqP ? | /eqP ?]; subst a; by contradict In; apply /negP.
Qed.

Lemma red_tens_upath_SomeNoneNot_ff (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  uacyclic (switching (G := G)) ->
  forall p u U,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub u U))) p ->
  forward (Some None) \in p ->
  forward None \notin p.
Proof.
  move => A p u U P SN; apply /negP => N.
  destruct (red_tens_upath_fN P) as [_ [HSN [_ _]]]. specialize (HSN SN).
  destruct HSN as [l [r ?]]; subst p.
  clear SN.
  revert N; rewrite mem_cat !in_cons /= => /orP N.
  wlog : u U l r P N / forward None \in r.
  { destruct N as [N | N].
    2:{ move => /(_ _ _ _ _ P) H. apply H; caseb. }
    destruct (supath_subKK P) as [L _].
    assert (Hr : upath_target (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) l =
      source (Some None : edge (red_tens_geos Hcut Het Hep Htens Hparr))).
    { revert P => /andP[/andP[Wl _] _].
      by rewrite (uwalk_sub_middle Wl). }
    rewrite Hr {Hr} /= in L.
    destruct (red_tens_upath_fN L) as [HN [_ [_ _]]]. specialize (HN N).
    destruct HN as [g [m ?]]; subst l.
    assert (P' := supath_turnsK P).
    assert (Hr : [:: forward (Some None), backward (Some (Some None)) & r] ++ g ++
      [:: forward None, backward (Some (Some (Some None))) & m] = [::] ++
      [:: forward (Some None), backward (Some (Some None)) & r ++ g ++
      [:: forward None, backward (Some (Some (Some None))) & m]]) by by [].
    rewrite Hr {Hr} in P'.
    move => /(_ _ _ _ _ P') H. apply H; rewrite !mem_cat !in_cons; caseb. }
  clear N => N.
  replace (l ++ [:: forward (Some None), backward (Some (Some None)) & r]) with
    ((l ++ [:: forward (Some None); backward (Some (Some None))]) ++ r) in P by by rewrite -catA.
  destruct (supath_subKK P) as [_ R].
  assert (Hr : upath_source (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) r =
    source (Some (Some None) : edge (red_tens_geos Hcut Het Hep Htens Hparr))).
  { revert P => /andP[/andP[W _] _].
    by rewrite -(uwalk_sub_middle W) upath_target_cat. }
  rewrite Hr {Hr} /= in R.
  destruct (red_tens_upath_fN R) as [HN [_ [_ _]]]. specialize (HN N).
  destruct HN as [m [d ?]]; subst r.
  clear N R.
  rewrite -catA in P.
  assert (SN : [forall b, (Some None, b) \notin m]).
  { apply /forallP => b.
    assert (M := supath_nin b P).
    by revert M; repeat (rewrite ?mem_cat ?in_cons /=); introb. }
  assert (N : [forall b, (None, b) \notin m]).
  { apply /forallP => b.
    rewrite !catA in P.
    assert (M := supath_nin b P).
    by revert M; repeat (rewrite ?mem_cat ?in_cons /=); introb. }
  rewrite catA in P.
  assert (M := supath_subK P).
  rewrite upath_target_cat /= in M.
  assert (SSN := red_tens_SNSSN M SN).
  assert (SSSN := red_tens_NSSSN M N).
  assert (NN : m <> nil).
  { intros ?; subst m.
    revert M; rewrite /supath; cbnb => /andP[/andP[/eqP Hc _] _].
    enough (Pc : supath switching (source (right (source et))) (source (right (source ep)))
      (forward (right (source et)) :: forward et :: backward ep :: backward (right (source ep)) :: nil)).
    { rewrite Hc in Pc.
      specialize (A _ {| upval := _ ; upvalK := Pc |}).
      contradict A; cbnb. }
    rewrite /supath /= !in_cons.
    destruct (red_tens_ineq_switching Hcut Het Hep Htens Hparr) as [? [_ [_ [_ [_ [_ [? [? [_ [? [_ [_ [? ?]]]]]]]]]]]]].
    repeat (apply /andP; split); repeat (apply /norP; split); trivial; apply /eqP;
    rewrite // ?right_e ?Het ?Hep; caseb. }
  destruct (red_tens_upath_Some NN M N SN SSN SSSN) as [x [X [y [Y [Hx [Hy Pxy]]]]]].
  revert Hx => /eqP; cbnb => /eqP ?; subst x.
  revert Hy => /eqP; cbnb => /eqP ?; subst y.
  enough (Pf : supath switching (source (right (source ep))) (source (right (source ep)))
    (forward (right (source ep)) :: forward ep :: backward et :: backward (right (source et)) ::
    (@red_tens_upath_bwd _ _ Hcut _ _ Het Hep Htens Hparr m))).
  { specialize (A _ {| upval := _ ; upvalK := Pf |}).
    contradict A; cbnb. }
  revert Pxy => /andP[/andP[Wn Un] ?].
  rewrite /supath /= !in_cons.
  destruct (red_tens_ineq_switching Hcut Het Hep Htens Hparr) as [? [_ [_ [_ [_ [_ [? [? [_ [? [_ [_ [? ?]]]]]]]]]]]]].
  destruct (red_tens_upath_bwd_nin_switching N SN SSN SSSN) as [? [? [? [? [? ?]]]]].
  splitb; simpl; try (by apply /eqP; apply nesym); rewrite ?right_e ?Het ?Hep; caseb.
Qed.

Lemma red_tens_upath_SomeNoneNot_fb (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  uacyclic (switching (G := G)) ->
  forall p u U,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub u U))) p ->
  forward (Some None) \in p ->
  backward None \notin p.
Proof.
  move => A p u U P SN; apply /negP => N.
  destruct (red_tens_upath_fN P) as [_ [HSN [_ _]]]. specialize (HSN SN).
  destruct HSN as [l [r ?]]; subst p.
  clear SN.
  revert N; rewrite mem_cat !in_cons /= => /orP N.
  wlog : u U l r P N / backward None \in r.
  { destruct N as [N | N].
    2:{ move => /(_ _ _ _ _ P) H. apply H; caseb. }
    destruct (supath_subKK P) as [L _].
    assert (Hr : upath_target (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) l =
      source (Some None : edge (red_tens_geos Hcut Het Hep Htens Hparr))).
    { revert P => /andP[/andP[Wl _] _].
      by rewrite (uwalk_sub_middle Wl). }
    rewrite Hr {Hr} /= in L.
    destruct (red_tens_upath_bN L) as [HN [_ [_ _]]]. specialize (HN N).
    destruct HN as [g [m ?]]; subst l.
    assert (P' := supath_turnsK P).
    assert (Hr : [:: forward (Some None), backward (Some (Some None)) & r] ++ g ++
      [:: forward (Some (Some (Some None))), backward None & m] = [::] ++
      [:: forward (Some None), backward (Some (Some None)) & r ++ g ++
      [:: forward (Some (Some (Some None))), backward None & m]]) by by [].
    rewrite Hr {Hr} in P'.
    move => /(_ _ _ _ _ P') H. apply H; rewrite !mem_cat !in_cons; caseb. }
  clear N => N.
  replace (l ++ [:: forward (Some None), backward (Some (Some None)) & r]) with
    ((l ++ [:: forward (Some None); backward (Some (Some None))]) ++ r) in P by by rewrite -catA.
  destruct (supath_subKK P) as [_ R].
  assert (Hr : upath_source (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) r =
    source (Some (Some None) : edge (red_tens_geos Hcut Het Hep Htens Hparr))).
  { revert P => /andP[/andP[W _] _].
    by rewrite -(uwalk_sub_middle W) upath_target_cat. }
  rewrite Hr {Hr} /= in R.
  destruct (red_tens_upath_bN R) as [HN [_ [_ _]]]. specialize (HN N).
  destruct HN as [m [d ?]]; subst r.
  clear N R.
  rewrite -catA in P.
  assert (SN : [forall b, (Some None, b) \notin m]).
  { apply /forallP => b.
    assert (M := supath_nin b P).
    by revert M; repeat (rewrite ?mem_cat ?in_cons /=); introb. }
  assert (N : [forall b, (None, b) \notin m]).
  { apply /forallP => b.
    rewrite !catA in P.
    assert (Hr : (((l ++ [:: forward (Some None); backward (Some (Some None))]) ++ m) ++
      [:: forward (Some (Some (Some None))), backward None & d]) = (((l ++
      [:: forward (Some None); backward (Some (Some None))]) ++ m ++
      [:: forward (Some (Some (Some None)))]) ++ backward None :: d)) by by rewrite -!catA.
    rewrite Hr {Hr} in P.
    assert (M := supath_nin b P).
    by revert M; repeat (rewrite ?mem_cat ?in_cons /=); introb. }
  rewrite catA in P.
  assert (M := supath_subK P).
  rewrite upath_target_cat /= in M.
  assert (SSN := red_tens_SNSSN M SN).
  assert (SSSN := red_tens_NSSSN M N).
  assert (NN : m <> nil).
  { intros ?; subst m.
    revert M; rewrite /supath; cbnb => /andP[/andP[/eqP Hc _] _].
    enough (Pc : supath switching (source (left (source et))) (source (right (source et)))
      [:: forward (left (source et)); backward (right (source et))]).
    { rewrite Hc in Pc.
      specialize (A _ {| upval := _ ; upvalK := Pc |}).
      contradict A; cbnb. }
    rewrite /supath /= !in_cons.
    destruct (red_tens_ineq_switching Hcut Het Hep Htens Hparr) as [_ [? [_ [_ [_ [_ [_ [_ [_ [_ [_ [_ [_ _]]]]]]]]]]]]].
    repeat (apply /andP; split); repeat (apply /norP; split); trivial; apply /eqP;
    rewrite // ?left_e ?right_e ?Het ?Hep; caseb. }
  destruct (red_tens_upath_Some NN M N SN SSN SSSN) as [x [X [y [Y [Hx [Hy Pxy]]]]]].
  revert Hx => /eqP; cbnb => /eqP ?; subst x.
  revert Hy => /eqP; cbnb => /eqP ?; subst y.
  enough (Pf : supath switching (source (left (source et))) (source (left (source et)))
    (forward (left (source et)) :: backward (right (source et)) ::
    (@red_tens_upath_bwd _ _ Hcut _ _ Het Hep Htens Hparr m))).
  { specialize (A _ {| upval := _ ; upvalK := Pf |}).
    contradict A; cbnb. }
  revert Pxy => /andP[/andP[Wn Un] ?].
  rewrite /supath /= !in_cons.
  destruct (red_tens_ineq_switching Hcut Het Hep Htens Hparr) as [_ [? [_ [_ [_ [_ [_ [_ [_ [_ [_ [_ [_ _]]]]]]]]]]]]].
  destruct (red_tens_upath_bwd_nin_switching N SN SSN SSSN) as [? [? [? [? [? ?]]]]].
  splitb; simpl; try (by apply /eqP; apply nesym); apply /eqP; rewrite ?left_e ?right_e ?Het ?Hep; caseb.
Qed.

Lemma red_tens_upath_SomeNoneNot (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  uacyclic (switching (G := G)) ->
  forall p u U b,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub u U))) p ->
  (Some None, b) \in p ->
  [forall c, (None, c) \notin p].
Proof.
  move => A p u U b.
  revert p u U.
  wlog: b / b = true.
  { move => /(_ true erefl) H p u U P SN. destruct b; [by apply (H _ _ _ P) | ].
    enough (Hd : [forall b, (None, b) \notin upath_rev p]).
    { apply /forallP => b. revert Hd => /forallP /(_ (~~b)).
      by rewrite (upath_rev_in p) negb_involutive. }
    apply (H _ _ _ (supath_revK P)).
    by rewrite (upath_rev_in p). }
  move => -> {b} p u U P SN.
  apply /forallPn. move => [[] /negPn N]; contradict N; apply /negP.
  - by apply (red_tens_upath_SomeNoneNot_ff A P).
  - by apply (red_tens_upath_SomeNoneNot_fb A P).
Qed.

Lemma red_tens_upath_NoneNot (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  uacyclic (switching (G := G)) ->
  forall p u U b,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub u U))) p ->
  (None, b) \in p ->
  [forall c, (Some None, c) \notin p].
Proof.
  move => A p u U b P In.
  apply /forallPn; move => [c /negPn Hc].
  assert (Nin := red_tens_upath_SomeNoneNot A P Hc).
  revert Nin => /forallP /(_ b) Nin.
  by contradict In; apply /negP.
Qed.

Lemma red_tens_uacyclic_notcut_None (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  uacyclic (switching (G := G)) -> forall u U b p,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub u U))) p ->
  (None, b) \in p ->
  p = [::].
Proof.
  move => A u U b.
  wlog: b / b = true.
  { move => /(_ true erefl) H p P N. destruct b; [by apply H | ].
    enough (Hd : upath_rev p = [::]).
    { destruct p as [ | [? ?] ?]; trivial. contradict Hd. apply rcons_nil. }
    apply H.
    - by apply supath_revK.
    - by rewrite (upath_rev_in p). }
  move => -> {b} p P N; cbn.
  assert (SN := red_tens_upath_NoneNot A P N).
  destruct (red_tens_upath_fN P) as [HN [_ [_ _]]]. specialize (HN N).
  destruct HN as [l [r ?]]; subst p.
  clear N.
  assert (P' : supath switching (source (Some (Some (Some None)) : edge (red_tens_geos Hcut Het Hep Htens Hparr)))
    (source (None : edge (red_tens_geos Hcut Het Hep Htens Hparr))) (r ++ l)).
  { clear - P.
    assert (P' := supath_turnsK P).
    assert (Hr : [:: forward None, backward (Some (Some (Some None))) & r] ++ l =
      [:: forward None; backward (Some (Some (Some None)))] ++ r ++ l) by by [].
    rewrite Hr {Hr} in P'.
    destruct (supath_subKK P') as [_ P''].
    revert P'; rewrite /supath => /andP[/andP[W _] _].
    by rewrite -(uwalk_sub_middle W) in P''. }
  assert (N' : [forall b, (None, b) \notin r ++ l]).
  { apply /forallP => b.
    assert (M := supath_nin b P).
    revert M; repeat (rewrite ?mem_cat ?in_cons /=); introb. splitb. }
  assert (SN' : [forall b, (Some None, b) \notin r ++ l]).
  { clear - SN. apply /forallP => b. revert SN => /forallP /(_ b).
    rewrite !mem_cat !in_cons. introb. splitb. }
  assert (SSN' := red_tens_SNSSN P' SN').
  assert (SSSN' := red_tens_NSSSN P' N').
  assert (NN' : r ++ l <> nil).
  { intros ?.
    assert (r = nil /\ l = nil) as [? ?] by by destruct r. subst r l.
    revert P; rewrite /supath cat0s => /andP[/andP[W _] _].
    revert W; cbn; rewrite !SubK => /andP[/eqP ? /eqP Hu]. subst u.
    enough (P : supath switching (source (left (source et))) (source (right (source ep)))
      (forward (left (source et)) :: forward et :: backward ep :: backward (right (source ep)) :: nil)).
    { rewrite Hu in P.
      specialize (A _ {| upval := _ ; upvalK := P |}).
      contradict A; cbnb. }
    rewrite /supath /= !in_cons.
    destruct (red_tens_ineq_switching Hcut Het Hep Htens Hparr) as [? [_ [? [? [_ [? [_ [_ [_ [_ [_ [_ [? ?]]]]]]]]]]]]].
    repeat (apply /andP; split); repeat (apply /norP; split); trivial; apply /eqP;
    rewrite // ?left_e ?right_e ?Het ?Hep; caseb. }
  destruct (red_tens_upath_Some NN' P' N' SN' SSN' SSSN') as [x [X [y [Y [Hx [Hy Pxy]]]]]].
  revert Hx => /eqP; cbnb => /eqP ?; subst x.
  revert Hy => /eqP; cbnb => /eqP ?; subst y.
  enough (Pf : supath switching (source (right (source ep))) (source (right (source ep)))
    (forward (right (source ep)) :: forward ep :: backward et :: backward (left (source et)) ::
    (@red_tens_upath_bwd _ _ Hcut _ _ Het Hep Htens Hparr (r ++ l)))).
  { specialize (A _ {| upval := _ ; upvalK := Pf |}).
    contradict A; cbnb. }
  revert Pxy => /andP[/andP[W Un] ?].
  rewrite /supath /= !in_cons.
  destruct (red_tens_ineq_switching Hcut Het Hep Htens Hparr) as [? [_ [? [? [_ [? [_ [_ [_ [_ [_ [_ [? ?]]]]]]]]]]]]].
  destruct (red_tens_upath_bwd_nin_switching N' SN' SSN' SSSN') as [? [? [? [? [? ?]]]]].
  splitb; simpl; try (by apply /eqP; apply nesym); rewrite // ?left_e ?right_e ?Het ?Hep; caseb.
Qed.

Lemma red_tens_uacyclic_notcut_SomeNone (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  uacyclic (switching (G := G)) -> forall u U b p,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub u U))) p ->
  (Some None, b) \in p ->
  p = [::].
Proof.
  move => A u U b.
  wlog: b / b = true.
  { move => /(_ true erefl) H p P SN. destruct b; [by apply H | ].
    enough (Hd : upath_rev p = [::]).
    { destruct p as [ | [? ?] ?]; trivial. contradict Hd. apply rcons_nil. }
    apply H.
    - by apply supath_revK.
    - by rewrite (upath_rev_in p). }
  move => -> {b} p P SN; cbn.
  assert (N := red_tens_upath_SomeNoneNot A P SN).
  destruct (red_tens_upath_fN P) as [_ [HSN [_ _]]]. specialize (HSN SN).
  destruct HSN as [l [r ?]]; subst p.
  clear SN.
  assert (P' : supath switching (source (Some (Some None) : edge (red_tens_geos Hcut Het Hep Htens Hparr)))
    (source (Some None : edge (red_tens_geos Hcut Het Hep Htens Hparr))) (r ++ l)).
  { clear - P.
    assert (P' := supath_turnsK P).
    assert (Hr : [:: forward (Some None), backward (Some (Some None)) & r] ++ l =
      [:: forward (Some None); backward (Some (Some None))] ++ r ++ l) by by [].
    rewrite Hr {Hr} in P'.
    destruct (supath_subKK P') as [_ P''].
    revert P'; rewrite /supath => /andP[/andP[W _] _].
    by rewrite -(uwalk_sub_middle W) in P''. }
  assert (N' : [forall b, (None, b) \notin r ++ l]).
  { clear - N. apply /forallP => b. revert N => /forallP /(_ b).
    rewrite !mem_cat !in_cons. introb. splitb. }
  assert (SN' : [forall b, (Some None, b) \notin r ++ l]).
  { apply /forallP => b.
    assert (M := supath_nin b P).
    revert M; repeat (rewrite ?mem_cat ?in_cons /=); introb. splitb. }
  assert (SSN' := red_tens_SNSSN P' SN').
  assert (SSSN' := red_tens_NSSSN P' N').
  assert (NN' : r ++ l <> nil).
  { intros ?.
    assert (r = nil /\ l = nil) as [? ?] by by destruct r. subst r l.
    revert P; rewrite /supath cat0s => /andP[/andP[W _] _].
    revert W; cbn; rewrite !SubK => /andP[/eqP ? /eqP Hu]. subst u.
    enough (P : supath switching (source (right (source et))) (source (left (source ep)))
      (forward (right (source et)) :: forward et :: backward ep :: backward (left (source ep)) :: nil)).
    { rewrite Hu in P.
      specialize (A _ {| upval := _ ; upvalK := P |}).
      contradict A; cbnb. }
    rewrite /supath /= !in_cons.
    destruct (red_tens_ineq_switching Hcut Het Hep Htens Hparr) as [? [? [? [? [? [? [? [? [? [? [? [? [? ?]]]]]]]]]]]]].
    repeat (apply /andP; split); repeat (apply /norP; split); trivial; apply /eqP;
    rewrite // ?left_e ?right_e ?Het ?Hep; caseb. }
  destruct (red_tens_upath_Some NN' P' N' SN' SSN' SSSN') as [x [X [y [Y [Hx [Hy Pxy]]]]]].
  revert Hx => /eqP; cbnb => /eqP ?; subst x.
  revert Hy => /eqP; cbnb => /eqP ?; subst y.
  enough (Pf : supath switching (source (left (source ep))) (source (left (source ep)))
    (forward (left (source ep)) :: forward ep :: backward et :: backward (right (source et)) ::
    (red_tens_upath_bwd (r ++ l)))).
  { specialize (A _ {| upval := _ ; upvalK := Pf |}).
    contradict A; cbnb. }
  revert Pxy => /andP[/andP[W Un] ?].
  rewrite /supath /= !in_cons.
  destruct (red_tens_ineq_switching Hcut Het Hep Htens Hparr) as [? [? [? [? [? [? [? [? [? [? [? [? [? ?]]]]]]]]]]]]].
  destruct (red_tens_upath_bwd_nin_switching N' SN' SSN' SSSN') as [? [? [? [? [? ?]]]]].
  splitb; simpl; try (by apply /eqP; apply nesym); rewrite // ?left_e ?right_e ?Het ?Hep; caseb.
Qed.

Lemma red_tens_uacyclic_notcut (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  uacyclic (switching (G := G)) -> forall u U p,
  supath switching (inl (inl (Sub u U)) : red_tens_geos Hcut Het Hep Htens Hparr) (inl (inl (Sub u U))) p ->
  p = [::].
Proof.
  move => A u U p P.
  remember ([forall b, (None, b) \notin p]) as Hn eqn:N; symmetry in N. destruct Hn.
  - remember ([forall b, (Some None, b) \notin p]) as Hsn eqn:SN; symmetry in SN. destruct Hsn.
    + apply (red_tens_uacyclic_nocut A P); trivial.
      * by apply (red_tens_SNSSN P).
      * by apply (red_tens_NSSSN P).
    + revert SN => /negP/negP/forallPn [b /negPn SN].
      apply (red_tens_uacyclic_notcut_SomeNone A P SN).
  - revert N => /negP/negP/forallPn [b /negPn N].
    apply (red_tens_uacyclic_notcut_None A P N).
Qed.

Lemma red_tens_uacyclic (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  uacyclic (switching (G := G)) ->
  uacyclic (switching (G := red_tens_geos Hcut Het Hep Htens Hparr)).
Proof.
  move => A [[[u U] | []] | []] [p P]; cbnb.
  { apply (red_tens_uacyclic_notcut A P). }
  all: destruct p as [ | (e, b) p]; trivial.
  all: assert (P' := supath_turnK P).
  all: revert P => /andP[/andP[/andP[? _] _] _].
  all: destruct e as [[[[[[[? ?] | []] | []] | ] | ] | ] | ], b; try by [].
  all: assert (N := red_tens_uacyclic_notcut A P').
  all: contradict N; apply rcons_nil.
Qed.

Lemma red_tens_ineq_if2 (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G) (Het : target et = v)
  (Hep : target ep = v) (Htens : vlabel (source et) = ⊗) (Hparr : vlabel (source ep) = ⅋) :
  left (source et) <> ep /\ left (source et) <> et /\
  right (source et) <> ep /\ right (source et) <> et /\
  left (source ep) <> ep /\ left (source ep) <> et /\
 right (source ep) <> ep /\ right (source ep) <> et.
Proof.
  splitb => Hc; subst; contradict Hcut.
  all: rewrite -1?Hc ?left_e ?right_e ?Htens ?Hparr; caseb.
  all: rewrite -1?Hep -1?Hc ?left_e ?right_e ?Htens ?Hparr; caseb.
Qed.

Lemma red_tens_nb_edges (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  #|edge G| = #|edge (red_tens_geos Hcut Het Hep Htens Hparr)| + 2.
Proof.
  enough (#|setT :\ et :\ ep| = #|edge (red_tens_geos Hcut Het Hep Htens Hparr)|) as <-.
  { rewrite -cardsT (cardsD1 et setT) (cardsD1 ep (setT :\ et)) !in_set.
    assert (ep != et = true) as ->.
    { apply /eqP => E. contradict Hparr. by rewrite E Htens. }
    lia. }
  rewrite -card_set_subset.
  set f : {e : edge G | (e \notin [set ep]) && (e \in [set: edge G] :\ et)} ->
    edge (red_tens_geos Hcut Het Hep Htens Hparr) :=
    fun e => if @boolP _ is AltTrue p then Some (Some (Some (Some (inl (inl (Sub (val e) p))))))
    else if val e == left (source et) then Some (Some (Some None))
    else if val e == right (source et) then Some (Some None)
    else if val e == left (source ep) then Some None
    else None. (* TODO pris dans left de red_tens -> en faire une def et la mettre à ce niveau *)
  assert (Hg : forall (e : edge (red_tens_geos Hcut Het Hep Htens Hparr)),
    (red_tens_transport e \notin [set ep]) && (red_tens_transport e \in [set: edge G] :\ et)).
  { move => e.
    rewrite !in_set /red_tens_transport.
    destruct (red_tens_ineq_if2 Hcut Het Hep Htens Hparr) as [? [? [? [? [? [? [? ?]]]]]]].
    destruct e as [[[[[[[e E] | []] | []] | ] | ] | ] | ]; splitb; apply /eqP => // ?; subst e.
    all: contradict E; apply /negP.
    all: rewrite !in_set; caseb. }
  set g : edge (red_tens_geos Hcut Het Hep Htens Hparr) ->
    {e : edge G | (e \notin [set ep]) && (e \in [set: edge G] :\ et)} :=
    fun e => Sub (red_tens_transport e) (Hg e).
  destruct (red_tens_ineq_if Hcut Het Hep Htens Hparr) as [? [? [? [? [? [? [? [? [? [? [? ?]]]]]]]]]]].
  apply (bij_card_eq (f := f)), (Bijective (g := g)).
  - move => [e E].
    rewrite /f /g SubK /red_tens_transport.
    case: {-}_ /boolP => In; cbnb.
    revert E; rewrite !in_set => /andP[/eqP Ep /andP[/eqP Et _]].
    case_if.
    revert In; rewrite !in_set =>
      /nandP[/nandP[/negPn/eqP He | /nandP[/negPn/eqP He | /nandP[/negPn/eqP He | //]]]
           | /nandP[/negPn/eqP He | /nandP[/negPn/eqP He | /nandP[/negPn/eqP He | //]]]].
    + assert (Hc := p_deg_out v). rewrite Hcut /= in Hc.
      assert (Hdone : e \in set0) by by rewrite -(cards0_eq Hc) in_set He.
      contradict Hdone; by rewrite in_set.
    + contradict Ep.
      transitivity (ccl (source ep)); [ | symmetry]; apply ccl_eq; caseb.
    + contradict Et.
      transitivity (ccl (source et)); [ | symmetry]; apply ccl_eq; caseb.
    + assert (T := target_in_edges_at_in e).
      rewrite He (red_tens_cut_set Hcut Het Hep Htens Hparr) !in_set in T.
      by revert T => /orP[/eqP ? | /eqP ?].
    + symmetry; apply right_eq; caseb.
    + by assert (e = right (source et)) by by apply right_eq; caseb.
  - move => e.
    rewrite /f /g SubK /red_tens_transport.
    destruct e as [[[[[[[e E] | []] | []] | ] | ] | ] | ].
    { case: {-}_ /boolP => Hc; [cbnb | ].
      by contradict Hc; apply /negP/negPn. }
    all: case: {-}_ /boolP => Hc; [ | case_if].
    all: contradict Hc; apply /negP.
    all: rewrite !in_set ?left_e ?right_e; caseb.
Qed.

Lemma red_tens_nb_parr (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  #|[set u : G | vlabel u == ⅋]| = #|[set u : red_tens_geos Hcut Het Hep Htens Hparr | vlabel u == ⅋]| + 1.
Proof.
  enough (#|[set u : G | vlabel u == ⅋] :\ (source ep)| =
    #|[set u : red_tens_geos Hcut Het Hep Htens Hparr | vlabel u == ⅋]|) as <-.
  { rewrite (cardsD1 (source ep) _) !in_set Hparr /=. lia. }
  rewrite -!card_set_subset.
  assert (Hf : forall (u : {u : G | (u \notin [set source ep]) && (u \in [set w | vlabel w == ⅋])}),
    val u \in [set: G] :\ (source et) :\ (source ep) :\ v).
  { move => [u U].
    rewrite SubK !in_set.
    revert U; rewrite !in_set => /andP[/eqP ? /eqP U].
    splitb; apply /eqP; trivial.
    all: move => ?; subst u; contradict U; by rewrite ?Hcut ?Htens. }
  assert (Hf' : forall (u : {u : G | (u \notin [set source ep]) && (u \in [set w | vlabel w == ⅋])}),
    vlabel (inl (inl (Sub (val u) (Hf u))) : red_tens_geos Hcut Het Hep Htens Hparr) == ⅋).
  { by move => [? /=]; rewrite !in_set => /andP[_ /eqP ->]. }
  set f : {u : G | (u \notin [set source ep]) && (u \in [set w | vlabel w == ⅋])} ->
    {u : red_tens_geos Hcut Het Hep Htens Hparr | vlabel u == ⅋} :=
    fun u => Sub (inl (inl (Sub (val u) (Hf u)))) (Hf' u).
  assert (Hg : forall (u : {u : red_tens_geos Hcut Het Hep Htens Hparr | vlabel u == ⅋}),
    match val u with
    | inl (inl u) => (val u \notin [set source ep]) && (val u \in [set w | vlabel w == ⅋])
    | _ => false
    end).
  { move => [[[[u Uin] | []] | []] /= U] //.
    revert Uin; rewrite !in_set => /andP[_ /andP[? _]]. splitb. }
  apply (bij_card_eq (f := f)). eapply Bijective. Unshelve. 3:{
    move => [[[u | []] | []] U] //. exact (Sub (val u) (Hg (Sub (inl (inl u)) U))). }
  - move => ?; cbnb.
  - move => [[[? | []] | []] ?]; cbnb.
Qed.

Lemma red_tens_uconnected (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  correct G ->
  uconnected (switching_left (G := red_tens_geos Hcut Het Hep Htens Hparr)).
Proof.
  move => [A C].
  assert (#|G| <> 0).
  { clear - v. rewrite -cardsT => Gc. apply cards0_eq in Gc.
    assert (V : v \in set0) by by rewrite -Gc !in_set. by rewrite in_set in V. }
  apply uconnected_to_nb1 in C; trivial; [ | apply switching_left_sinj].
  assert (N := switching_left_uconnected_nb A).
  apply uconnected_from_nb1; [apply switching_left_sinj | ].
  assert (N' := switching_left_uconnected_nb (@red_tens_uacyclic _ _ Hcut _ _ Het Hep Htens Hparr A)).
  rewrite (red_tens_nb_edges Hcut Het Hep Htens Hparr) (red_tens_nb_parr Hcut Het Hep Htens Hparr) in N.
  rewrite red_tens_nb in N'.
  lia.
Qed.

Lemma red_tens_correct (G : geos) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) :
  correct G -> correct (red_tens_geos Hcut Het Hep Htens Hparr).
Proof.
  move => [A C]. split.
  - by apply red_tens_uacyclic.
  - by apply red_tens_uconnected.
Qed.

Definition red_tens_pn (G : proof_net) (v : G) (Hcut : vlabel v = cut) (et ep : edge G)
  (Het : target et = v) (Hep : target ep = v) (Htens : vlabel (source et) = ⊗)
  (Hparr : vlabel (source ep) = ⅋) : proof_net := {|
  ps_of := red_tens_ps Hcut Het Hep Htens Hparr;
  p_correct := @red_tens_correct _ _ _ _ _ _ _ _ _ (p_correct G);
  |}.


(** * Cut reduction procedure *)
Lemma red_term (G : proof_structure) (v : G) (H : vlabel v = cut) :
  [exists e, (target e == v) && (vlabel (source e) == ax)] || [exists et, exists ep,
  (target et == v) && (target ep == v) && (vlabel (source et) == ⊗) && (vlabel (source ep) == ⅋)].
Proof.
  enough (Hdone : (exists e, target e = v /\ vlabel (source e) = ax) \/
    exists et ep, target et = v /\ target ep = v /\ vlabel (source et) = ⊗ /\ vlabel (source ep) = ⅋).
  { destruct Hdone as [[e [He0 He1]] | [et [ep [He0 [He1 [He2 He3]]]]]].
    - apply /orP; left. apply /existsP; exists e. rewrite He0 He1. splitb.
    - apply /orP; right. apply /existsP; exists et. apply /existsP; exists ep. rewrite He0 He1 He2 He3. splitb. }
  destruct (p_cut H) as [e [e' H']];
  revert H'; rewrite !in_set => /andP[/andP[/eqP Hin /eqP Hin'] /eqP Heq].
  rewrite -Hin in H.
  assert (Hout := p_deg_out (source e)).
  assert (Hout' := p_deg_out (source e')).
  assert (#|edges_at_out (source e)| <> 0 /\ #|edges_at_out (source e')| <> 0) as [? ?].
  { split; intro Hc; [set f := e | set f := e'].
    all: assert (Hf : f \in set0) by by rewrite -(cards0_eq Hc) in_set.
    all: contradict Hf; by rewrite in_set. }
  destruct (vlabel (source e)) eqn:Hle; try done;
  destruct (vlabel (source e')) eqn:Hle'; try done.
  all: try (by left; exists e; splitb).
  all: try (by left; exists e'; splitb).
  - contradict Heq.
    enough (elabel e = tens (elabel (left (source e))) (elabel (right (source e)))
      /\ elabel e' = tens (elabel (left (source e'))) (elabel (right (source e')))) as [-> ->] by by [].
    assert (e = ccl (source e) /\ e' = ccl (source e')) as [He He'] by (split; apply ccl_eq; trivial; caseb).
    split; [rewrite {1}He | rewrite {1}He']; by apply p_tens.
  - right; by exists e, e'.
  - right; by exists e', e.
  - contradict Heq.
    enough (elabel e = parr (elabel (left (source e))) (elabel (right (source e)))
      /\ elabel e' = parr (elabel (left (source e'))) (elabel (right (source e')))) as [-> ->] by by [].
    assert (e = ccl (source e) /\ e' = ccl (source e')) as [He He'] by (split; apply ccl_eq; trivial; caseb).
    split; [rewrite {1}He | rewrite {1}He']; by apply p_parr.
Qed.

(** One step *)
Definition red_one_ps (G : proof_structure) (v : G) (H : vlabel v = cut) : proof_structure.
Proof.
  elim: (orb_sum (red_term H)).
  - move => /existsP/sigW[? /andP[/eqP ? /eqP ?]]; subst.
    by apply (red_ax_ps H).
  - move => /existsP/sigW [? /existsP/sigW[? /andP[/andP[/andP[/eqP Het /eqP Hep] /eqP ?] /eqP ?]]].
    by apply (red_tens_ps H Het Hep).
Defined.

Lemma red_one_correct (G : proof_net) (v : G) (H : vlabel v = cut) :
  correct (red_one_ps H).
Proof.
  unfold red_one_ps.
  elim: (orb_sum (red_term H)) => ? /=.
  - elim: (sigW _) => ? /andP[He ?].
    set Hr := elimTF eqP He; destruct Hr.
    apply (red_ax_correct _ _ (p_correct G)).
  - elim: (sigW _) => ? ?;
    elim: (sigW _) => ? /andP[/andP[/andP[? ?] ?] ?].
    apply (red_tens_correct _ _ _ _ _ (p_correct G)).
Qed.

Definition red_one_pn (G : proof_net) (v : G) (H : vlabel v = cut) : proof_net := {|
  ps_of := red_one_ps H;
  p_correct := red_one_correct _;
  |}.

Lemma red_one_sequent (G : proof_structure) (v : G) (H : vlabel v = cut) :
  sequent (red_one_ps H) = sequent G.
Proof.
  unfold red_one_ps.
  elim: (orb_sum (red_term H)) => ? /=.
  - elim: (sigW _) => ? /andP[He ?]. set Hr := elimTF eqP He; destruct Hr.
    apply red_ax_sequent.
  - elim: (sigW _) => ? ?; elim: (sigW _) => ? /andP[/andP[/andP[? ?] ?] ?].
    apply red_tens_sequent.
Qed.

Lemma red_one_nb (G : proof_structure) (v : G) (H : vlabel v = cut) :
  #|red_one_ps H| < #|G|.
Proof.
  unfold red_one_ps.
  assert (#|G| <> 0) by by apply fintype0.
  elim: (orb_sum (red_term H)) => ? /=.
  - elim: (sigW _) => e /andP[He Hax]. set Hr := elimTF eqP He; destruct Hr.
    rewrite red_ax_nb.
    set n := #|G|; lia.
  - elim: (sigW _) => *. elim: (sigW _); introb.
    rewrite red_tens_nb //; try by apply /eqP.
    set n := #|G|; lia.
Qed.

(** All steps *)
Definition has_cut (G : base_graph) := #|[set v : G | vlabel v == cut]| != 0.

Lemma has_cutP (G : base_graph) : reflect (has_cut G) [exists v : G, vlabel v == cut].
Proof.
  apply iff_reflect; split; unfold has_cut; intro H.
  - rewrite eqn0Ngt negb_involutive card_gt0 in H. revert H => /set0Pn [e H].
    rewrite in_set in H.
    apply /existsP. by exists e.
  - revert H => /existsP [v Hm].
    rewrite eqn0Ngt negb_involutive card_gt0.
    apply /set0Pn. exists v. by rewrite in_set.
Qed. (* TODO dans def ? *)

(* Fixpoint red_all (G : proof_structure) n {struct n}:  #|G| = n -> {P : proof_structure | sequent P = sequent G & ~(has_cut P)}.
Proof.
move => N.
  have [H | H] := altP (@has_cutP G).
  + revert H => /has_cutP /existsP /sigW [v /eqP Hcut].
    rewrite -(red_one_sequent Hcut).
    assert (Hc' := red_one_nb Hcut).
    apply (red_all (red_one_ps Hcut) #|red_one_ps Hcut|); lia.
  + revert H => /has_cutP H.
    by exists G.
Defined. *)

(* TODO possible d'unifier les 2 red_all ? *)
Definition red_all (G : proof_structure) : {P : proof_structure | sequent P = sequent G & ~(has_cut P)}.
Proof.
  revert G.
  enough (Hm : forall n (G : proof_structure), #|G| = n ->
    {P : proof_structure | sequent P = sequent G & ~(has_cut P)})
    by (intro G; by apply (Hm #|G|)).
  intro n; induction n as [n IH] using lt_wf_rect; intros G Hc.
  have [H | H] := altP (@has_cutP G).
  + revert H => /has_cutP /existsP /sigW [v /eqP Hcut].
    rewrite -(red_one_sequent Hcut).
    assert (Hc' := red_one_nb Hcut).
    apply (IH #|red_one_ps Hcut|); lia.
  + revert H => /has_cutP H.
    by exists G.
Defined.

Definition red (G : proof_structure) : proof_structure := proj1_sig (red_all G).

Lemma red_sequent (G : proof_structure) : sequent (red G) = sequent G.
Proof. by destruct (proj2_sig (red_all G)). Qed.

Lemma red_has_cut (G : proof_structure) : ~ has_cut (red G).
Proof. by destruct (proj2_sig (red_all G)). Qed.

Definition red_all' (G : proof_net) : {P : proof_net | sequent P = sequent G & ~(has_cut P)}.
Proof.
  revert G.
  enough (Hm : forall n (G : proof_net), #|G| = n ->
    {P : proof_net | sequent P = sequent G & ~(has_cut P)})
    by by intro G; apply (Hm #|G|).
  move => n; induction n as [n IH] using lt_wf_rect => G Hc.
  have [H | H] := altP (@has_cutP G).
  + revert H => /has_cutP/existsP/sigW[v /eqP Hcut].
    rewrite -(red_one_sequent Hcut).
    refine (IH #|red_one_ps Hcut| _ (red_one_pn Hcut) _); trivial.
    rewrite -Hc.
    apply /leP. apply red_one_nb.
  + revert H => /has_cutP H.
    by exists G.
Defined.

Definition red' (G : proof_net) : proof_net := proj1_sig (red_all' G).

Lemma red_sequent' (G : proof_net) : sequent (red' G) = sequent G.
Proof. by destruct (proj2_sig (red_all' G)). Qed.

Lemma red_has_cut' (G : proof_net) : ~ has_cut (red' G).
Proof. by destruct (proj2_sig (red_all' G)). Qed.





Fixpoint nb_cut l (pi : ll l) := match pi with
  | ax_r x                 => 0
  | ex_r _ _ pi0 _         => nb_cut pi0
  | tens_r _ _ _ _ pi0 pi1 => nb_cut pi0 + nb_cut pi1
  | parr_r _ _ _ pi0       => nb_cut pi0
  | cut_r _ _ _ pi0 pi1    => nb_cut pi0 + nb_cut pi1 + 1
  end.
(* UTILISE ps, AUTRE FICHIER 
Lemma ps_nb_cut l (pi : ll l) : #|[set v : ps pi | vlabel v == cut]| = nb_cut pi.
Proof.
  induction pi as [x | | A B l0 l1 pi0 H0 pi1 H1 | A B l0 pi0 H0 | A l0 l1 pi0 H0 pi1 H1].
  - enough (H : [set v : ax_ps x | vlabel v == cut] = set0) by by rewrite H cards0.
    apply /setP; intro v; destruct_I3 v;
    by rewrite !in_set.
  - by [].
  - rewrite /= -H0 -H1.
Abort. *)
(* TODO Lemma : nb cut ps (pi) = nb cut pi, idem other rules + mettre ça vers ps
-> vraiment utile ? ça a l'air mieux dans le sens sequentialisation ... *)

(* lemma: sub-confluence + convergence *)
End Atoms.
