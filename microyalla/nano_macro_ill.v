Require Import List.

Require Import Permutation_Type.

Require Import ill_def nanoill.

Fixpoint ill2ill A :=
match A with
| ivar x    => iformulas.ivar (Some x)
| itens A B => iformulas.itens (ill2ill A) (ill2ill B)
| ilmap A B => iformulas.ilmap (ill2ill A) (ill2ill B)
| ione      => iformulas.ione
| iwith A B => iformulas.iwith (ill2ill A) (ill2ill B)
| iplus A B => iformulas.iplus (ill2ill A) (ill2ill B)
| itop      => iformulas.itop
| izero     => iformulas.izero
| ioc A     => iformulas.ioc (ill2ill A)
end.

Lemma ill2ill_map_ioc : forall l,
  map ill2ill (map ioc l) = map iformulas.ioc (map ill2ill l).
Proof with try reflexivity.
induction l...
simpl ; rewrite IHl...
Qed.

Definition ipfrag_ill := ill_def.mk_ipfrag false ill_def.NoIAxioms true.
(*                                         cut   axioms            perm  *)

Theorem ill2ill_proof : forall l A, ill l A -> ill_def.ill ipfrag_ill (map ill2ill l) (ill2ill A).
Proof.
intros l A pi.
induction pi; rewrite <- (app_nil_l _) ; try (now constructor).
- eapply ex_ir; [ eassumption | simpl ].
  apply Permutation_Type_map.
  apply Permutation_Type_app_head.
  apply Permutation_Type_swap.
- now rewrite map_app; rewrite app_nil_l ; constructor.
- apply (ex_ir _ (nil ++ map ill2ill l1 ++ iformulas.ilmap (ill2ill A) (ill2ill B) :: map ill2ill l2)).
  + now constructor.
  + simpl; rewrite map_app.
    etransitivity; [ apply Permutation_Type_app_comm | ].
    apply Permutation_Type_cons; try reflexivity.
    apply Permutation_Type_app_comm.
- rewrite ill2ill_map_ioc.
  constructor.
  rewrite <- ill2ill_map_ioc; assumption.
Qed.
