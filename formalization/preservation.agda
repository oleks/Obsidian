open import Silica
open import HeapProperties
import Context

open TypeEnvContext

open import Data.Nat
open import Relation.Nullary using (¬_; Dec; yes; no)
open import Data.Empty
import Relation.Binary.PropositionalEquality as Eq



data Preservation : Expr → Set where
  pres : ∀ {e e' : Expr}
       → ∀ {T T' : Type}
       → ∀ {Δ Δ'' Δ''' : StaticEnv}
       → ∀ {Σ Σ' : RuntimeEnv }
       → Δ ⊢ e ⦂ T ⊣ Δ'' 
       → Σ & Δ ok        
       -- TODO: hdref(e)
       → Σ , e ⟶ Σ' , e'
       → (Δ' : StaticEnv)
       → (Δ' ⊢ e' ⦂ T' ⊣ Δ''') 
       → (Σ' & Δ' ok)  -- 
       → (Δ''' <* Δ'')
       -----------------
       → Preservation e

splitIdempotent : ∀ {Γ T₁ T₂ T₃}
                    → Γ ⊢ T₁ ⇛ T₂ / T₃
                    → Γ ⊢ T₂ ⇛ T₂ / T₃ 
splitIdempotent {Γ} {.(base Void)} {.(base Void)} {.(base Void)} voidSplit = voidSplit
splitIdempotent {Γ} {.(base Boolean)} {.(base Boolean)} {.(base Boolean)} booleanSplit = booleanSplit
splitIdempotent {Γ} {.(contractType _)} {.(contractType _)} {.(contractType _)} (unownedSplit namesEq1 namesEq2 permsEq permUnowned) =
  unownedSplit refl (Eq.trans (Eq.sym namesEq1) namesEq2) refl permUnowned
splitIdempotent {Γ} {.(contractType _)} {.(contractType _)} {.(contractType _)} (shared-shared-shared x) =
  shared-shared-shared x
splitIdempotent {Γ} {.(contractType (tc _ Owned))} {.(contractType (tc _ Shared))} {.(contractType (tc _ Shared))} (owned-shared x) =
  shared-shared-shared refl
splitIdempotent {Γ} {.(contractType (record { contractName = _ ; perm = S _ }))}
                    {.(contractType (record { contractName = _ ; perm = Shared }))}
                    {.(contractType (record { contractName = _ ; perm = Shared }))}
                    (states-shared x) =
                    shared-shared-shared refl

preservation : ∀ {e e' : Expr}
               → ∀ {T : Type}
               → ∀ {Δ Δ'' : StaticEnv}
               → ∀ {Σ Σ' : RuntimeEnv}
               → Δ ⊢ e ⦂ T ⊣ Δ'' 
               → Σ & Δ ok   
               → Σ , e ⟶ Σ' , e'
               -----------------------
               → Preservation e

-- Proof proceeds by induction on the dynamic semantics.

preservation ty@(locTy {Γ} {Δ₀} l voidSplit) consis st@(SElookup {l = l} {v = voidVal} _ lookupL) =
  let
    Δ = (Δ₀ ,ₗ l ⦂ base Void)
    Δ' = Δ
    e'TypingJudgment = voidTy {Γ} {Δ = Δ'}
  in 
    pres ty consis st Δ' e'TypingJudgment consis <*-refl
preservation ty@(locTy {Γ} {Δ₀} l booleanSplit) consis st@(SElookup {l = l} {v = boolVal b} _ lookupL) = 
 let
    Δ = (Δ₀ ,ₗ l ⦂ base Boolean)
    Δ' = Δ
    e'TypingJudgment = boolTy {Γ} {Δ = Δ'} b
  in 
    pres {Δ = Δ} ty consis st Δ' e'TypingJudgment consis <*-refl
-- The code duplication below is very sad, but I haven't figured out a way that doesn't require refactoring the split judgment to be two-level.
preservation ty@(locTy {Γ} {Δ₀} {T₁ = contractType t₁} {T₂ = contractType t₂} {T₃ = contractType t₃} l spl@(unownedSplit _ _ _ _))
                       consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
                       st@(SElookup {Σ} {l = l} {v = objVal o} _ lookupL) = 
  let
    spl' = splitIdempotent spl
    e'TypingJudgment = objTy {Γ} {Δ = Δ''} {T₁ = contractType t₂} {T₂ = contractType t₂} {T₃ = contractType t₃} o spl'
   
    consis' = ok {Σ} Δ' voidLookup' boolLookup' objLookup' refConsistency'
  in
    pres {_} {_} {_} {_} {Δ = Δ} {Δ'' = Δ''} {_} {_} {_} ty consis st Δ' e'TypingJudgment consis' <*-o-extension
  where
    splT = splitType spl
    Δ'' = Δ₀ ,ₗ l ⦂ (SplitType.t₃ splT) -- This is the result of checking e.
    Δ' = Δ'' ,ₒ o ⦂ (SplitType.t₂ splT) -- This is the typing context in which we need to typecheck e'.
    --Δ = Δ₀ ,ₗ l ⦂ (SplitType.t₁ splT)
    -- Show that if you look up l in the new context, you get the same type as before.
    voidLookup' : (∀ (l' : IndirectRef)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Void
                  → (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ voidVal)))
    voidLookup' l' l'InΔ' with l' Data.Nat.≟ l
    voidLookup' l' (Context.S l'NeqL l'VoidType) | yes eq = ⊥-elim (l'NeqL eq)
    voidLookup' l' l'InΔ' | no nEq = voidLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))

    boolLookup' : (∀ (l' : IndirectRef)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Boolean
                  → ∃[ b ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ boolVal b)))
    boolLookup' l' l'InΔ' with l' Data.Nat.≟ l
    boolLookup' l' (Context.S l'NeqL l'BoolType) | yes eq = ⊥-elim (l'NeqL eq)
    boolLookup' l' l'InΔ' | no nEq = boolLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
    
    objLookup' : (l' : IndirectRef) → (T : Tc)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ (contractType T)
                  → ∃[ o ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ objVal o × (o ObjectRefContext.∈dom (RuntimeEnv.μ Σ))))
    objLookup' l' _ l'InΔ' with l' Data.Nat.≟ l
    objLookup' l' _ (Context.S l'NeqL l'ObjType) | yes eq = ⊥-elim (l'NeqL eq)
    objLookup' l' t l'InΔ'@(Z {a = contractType t₃}) | yes eq = objLookup l' t₁ Z
    objLookup' l' t l'InΔ' | no nEq = objLookup l' t (S nEq (irrelevantReductionsOK l'InΔ' nEq))

    lookupUnique : objVal o ≡ objVal ( proj₁ (objLookup l t₁ Z))
    lookupUnique = IndirectRefContext.contextLookupUnique {RuntimeEnv.ρ Σ} lookupL (proj₁ (proj₂ (objLookup l t₁ Z)))
    oLookupUnique = objValInjectiveContrapositive lookupUnique

    -- Show that all location-based aliases from the previous environment are compatible with the new alias.
    -- Note that Σ is unchanged, so we use Σ instead of defining a separate Σ'.
    refConsistency' : (o' : ObjectRef) → o' ObjectRefContext.∈dom (RuntimeEnv.μ Σ) → ReferenceConsistency Σ Δ' o'
    refConsistency' o' o'Inμ =
      let
        origRefConsistency = refConsistencyFunc o' o'Inμ
        origConnected =  referencesConsistentImpliesConnectivity origRefConsistency
        newConnected = splitReplacementOK {Γ} {Σ} {Δ₀} {o} {o'} {l} {t₁} {t₂} {SplitType.t₁ splT} {SplitType.t₂ splT} {SplitType.t₃ splT}
                                          refl refl consis oLookupUnique (proj₁ origConnected) (proj₂ origConnected) spl
      in 
        referencesConsistent {_} {_} {o'} newConnected
                       
preservation ty@(locTy {Γ} {Δ₀} {T₁ = contractType t₁} {T₂ = contractType t₂} {T₃ = contractType t₃} l spl@(shared-shared-shared _))
                       consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
                       st@(SElookup {Σ} {l = l} {v = objVal o} _ lookupL) = 
   let
    spl' = splitIdempotent spl
    e'TypingJudgment = objTy {Γ} {Δ = Δ''} {T₁ = contractType t₂} {T₂ = contractType t₂} {T₃ = contractType t₃} o spl'
   
    consis' = ok {Σ} Δ' voidLookup' boolLookup' objLookup' refConsistency'
  in
    pres {_} {_} {_} {_} {Δ = Δ} {Δ'' = Δ''} {_} {_} {_} ty consis st Δ' e'TypingJudgment consis' <*-o-extension
  where
    splT = splitType spl
    Δ'' = Δ₀ ,ₗ l ⦂ (SplitType.t₃ splT) -- This is the result of checking e.
    Δ' = Δ'' ,ₒ o ⦂ (SplitType.t₂ splT) -- This is the typing context in which we need to typecheck e'.
    --Δ = Δ₀ ,ₗ l ⦂ (SplitType.t₁ splT)
    -- Show that if you look up l in the new context, you get the same type as before.
    voidLookup' : (∀ (l' : IndirectRef)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Void
                  → (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ voidVal)))
    voidLookup' l' l'InΔ' with l' Data.Nat.≟ l
    voidLookup' l' (Context.S l'NeqL l'VoidType) | yes eq = ⊥-elim (l'NeqL eq)
    voidLookup' l' l'InΔ' | no nEq = voidLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))

    boolLookup' : (∀ (l' : IndirectRef)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Boolean
                  → ∃[ b ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ boolVal b)))
    boolLookup' l' l'InΔ' with l' Data.Nat.≟ l
    boolLookup' l' (Context.S l'NeqL l'BoolType) | yes eq = ⊥-elim (l'NeqL eq)
    boolLookup' l' l'InΔ' | no nEq = boolLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
    
    objLookup' : (l' : IndirectRef) → (T : Tc)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ (contractType T)
                  → ∃[ o ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ objVal o × (o ObjectRefContext.∈dom (RuntimeEnv.μ Σ))))
    objLookup' l' _ l'InΔ' with l' Data.Nat.≟ l
    objLookup' l' _ (Context.S l'NeqL l'ObjType) | yes eq = ⊥-elim (l'NeqL eq)
    objLookup' l' t l'InΔ'@(Z {a = contractType t₃}) | yes eq = objLookup l' t₁ Z
    objLookup' l' t l'InΔ' | no nEq = objLookup l' t (S nEq (irrelevantReductionsOK l'InΔ' nEq))

    lookupUnique : objVal o ≡ objVal ( proj₁ (objLookup l t₁ Z))
    lookupUnique = IndirectRefContext.contextLookupUnique {RuntimeEnv.ρ Σ} lookupL (proj₁ (proj₂ (objLookup l t₁ Z)))
    oLookupUnique = objValInjectiveContrapositive lookupUnique

    -- Show that all location-based aliases from the previous environment are compatible with the new alias.
    -- Note that Σ is unchanged, so we use Σ instead of defining a separate Σ'.
    refConsistency' : (o' : ObjectRef) → o' ObjectRefContext.∈dom (RuntimeEnv.μ Σ) → ReferenceConsistency Σ Δ' o'
    refConsistency' o' o'Inμ =
      let
        origRefConsistency = refConsistencyFunc o' o'Inμ
        origConnected =  referencesConsistentImpliesConnectivity origRefConsistency
        newConnected = splitReplacementOK {Γ} {Σ} {Δ₀} {o} {o'} {l} {t₁} {t₂} {SplitType.t₁ splT} {SplitType.t₂ splT} {SplitType.t₃ splT}
                                          refl refl consis oLookupUnique (proj₁ origConnected) (proj₂ origConnected) spl
      in 
        referencesConsistent {_} {_} {o'} newConnected
preservation ty@(locTy {Γ} {Δ₀} {T₁ = contractType t₁} {T₂ = contractType t₂} {T₃ = contractType t₃} l spl@(owned-shared _))
                       consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
                       st@(SElookup {Σ} {l = l} {v = objVal o} _ lookupL) = 
   let
    spl' = splitIdempotent spl
    e'TypingJudgment = objTy {Γ} {Δ = Δ''} {T₁ = contractType t₂} {T₂ = contractType t₂} {T₃ = contractType t₃} o spl'
   
    consis' = ok {Σ} Δ' voidLookup' boolLookup' objLookup' refConsistency'
  in
    pres {_} {_} {_} {_} {Δ = Δ} {Δ'' = Δ''} {_} {_} {_} ty consis st Δ' e'TypingJudgment consis' <*-o-extension
  where
    splT = splitType spl
    Δ'' = Δ₀ ,ₗ l ⦂ (SplitType.t₃ splT) -- This is the result of checking e.
    Δ' = Δ'' ,ₒ o ⦂ (SplitType.t₂ splT) -- This is the typing context in which we need to typecheck e'.
    --Δ = Δ₀ ,ₗ l ⦂ (SplitType.t₁ splT)
    -- Show that if you look up l in the new context, you get the same type as before.
    voidLookup' : (∀ (l' : IndirectRef)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Void
                  → (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ voidVal)))
    voidLookup' l' l'InΔ' with l' Data.Nat.≟ l
    voidLookup' l' (Context.S l'NeqL l'VoidType) | yes eq = ⊥-elim (l'NeqL eq)
    voidLookup' l' l'InΔ' | no nEq = voidLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))

    boolLookup' : (∀ (l' : IndirectRef)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Boolean
                  → ∃[ b ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ boolVal b)))
    boolLookup' l' l'InΔ' with l' Data.Nat.≟ l
    boolLookup' l' (Context.S l'NeqL l'BoolType) | yes eq = ⊥-elim (l'NeqL eq)
    boolLookup' l' l'InΔ' | no nEq = boolLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
    
    objLookup' : (l' : IndirectRef) → (T : Tc)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ (contractType T)
                  → ∃[ o ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ objVal o × (o ObjectRefContext.∈dom (RuntimeEnv.μ Σ))))
    objLookup' l' _ l'InΔ' with l' Data.Nat.≟ l
    objLookup' l' _ (Context.S l'NeqL l'ObjType) | yes eq = ⊥-elim (l'NeqL eq)
    objLookup' l' t l'InΔ'@(Z {a = contractType t₃}) | yes eq = objLookup l' t₁ Z
    objLookup' l' t l'InΔ' | no nEq = objLookup l' t (S nEq (irrelevantReductionsOK l'InΔ' nEq))

    lookupUnique : objVal o ≡ objVal ( proj₁ (objLookup l t₁ Z))
    lookupUnique = IndirectRefContext.contextLookupUnique {RuntimeEnv.ρ Σ} lookupL (proj₁ (proj₂ (objLookup l t₁ Z)))
    oLookupUnique = objValInjectiveContrapositive lookupUnique

    -- Show that all location-based aliases from the previous environment are compatible with the new alias.
    -- Note that Σ is unchanged, so we use Σ instead of defining a separate Σ'.
    refConsistency' : (o' : ObjectRef) → o' ObjectRefContext.∈dom (RuntimeEnv.μ Σ) → ReferenceConsistency Σ Δ' o'
    refConsistency' o' o'Inμ =
      let
        origRefConsistency = refConsistencyFunc o' o'Inμ
        origConnected =  referencesConsistentImpliesConnectivity origRefConsistency
        newConnected = splitReplacementOK {Γ} {Σ} {Δ₀} {o} {o'} {l} {t₁} {t₂} {SplitType.t₁ splT} {SplitType.t₂ splT} {SplitType.t₃ splT}
                                          refl refl consis oLookupUnique (proj₁ origConnected) (proj₂ origConnected) spl
      in 
        referencesConsistent {_} {_} {o'} newConnected
preservation ty@(locTy {Γ} {Δ₀} {T₁ = contractType t₁} {T₂ = contractType t₂} {T₃ = contractType t₃} l spl@(states-shared _))
                       consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
                       st@(SElookup {Σ} {l = l} {v = objVal o} _ lookupL) = 
   let
    spl' = splitIdempotent spl
    e'TypingJudgment = objTy {Γ} {Δ = Δ''} {T₁ = contractType t₂} {T₂ = contractType t₂} {T₃ = contractType t₃} o spl'
   
    consis' = ok {Σ} Δ' voidLookup' boolLookup' objLookup' refConsistency'
  in
    pres {_} {_} {_} {_} {Δ = Δ} {Δ'' = Δ''} {_} {_} {_} ty consis st Δ' e'TypingJudgment consis' <*-o-extension
  where
    splT = splitType spl
    Δ'' = Δ₀ ,ₗ l ⦂ (SplitType.t₃ splT) -- This is the result of checking e.
    Δ' = Δ'' ,ₒ o ⦂ (SplitType.t₂ splT) -- This is the typing context in which we need to typecheck e'.
    --Δ = Δ₀ ,ₗ l ⦂ (SplitType.t₁ splT)
    -- Show that if you look up l in the new context, you get the same type as before.
    voidLookup' : (∀ (l' : IndirectRef)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Void
                  → (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ voidVal)))
    voidLookup' l' l'InΔ' with l' Data.Nat.≟ l
    voidLookup' l' (Context.S l'NeqL l'VoidType) | yes eq = ⊥-elim (l'NeqL eq)
    voidLookup' l' l'InΔ' | no nEq = voidLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))

    boolLookup' : (∀ (l' : IndirectRef)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Boolean
                  → ∃[ b ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ boolVal b)))
    boolLookup' l' l'InΔ' with l' Data.Nat.≟ l
    boolLookup' l' (Context.S l'NeqL l'BoolType) | yes eq = ⊥-elim (l'NeqL eq)
    boolLookup' l' l'InΔ' | no nEq = boolLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
    
    objLookup' : (l' : IndirectRef) → (T : Tc)
                  → ((StaticEnv.locEnv Δ') ∋ l' ⦂ (contractType T)
                  → ∃[ o ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ objVal o × (o ObjectRefContext.∈dom (RuntimeEnv.μ Σ))))
    objLookup' l' _ l'InΔ' with l' Data.Nat.≟ l
    objLookup' l' _ (Context.S l'NeqL l'ObjType) | yes eq = ⊥-elim (l'NeqL eq)
    objLookup' l' t l'InΔ'@(Z {a = contractType t₃}) | yes eq = objLookup l' t₁ Z
    objLookup' l' t l'InΔ' | no nEq = objLookup l' t (S nEq (irrelevantReductionsOK l'InΔ' nEq))

    lookupUnique : objVal o ≡ objVal ( proj₁ (objLookup l t₁ Z))
    lookupUnique = IndirectRefContext.contextLookupUnique {RuntimeEnv.ρ Σ} lookupL (proj₁ (proj₂ (objLookup l t₁ Z)))
    oLookupUnique = objValInjectiveContrapositive lookupUnique

    -- Show that all location-based aliases from the previous environment are compatible with the new alias.
    -- Note that Σ is unchanged, so we use Σ instead of defining a separate Σ'.
    refConsistency' : (o' : ObjectRef) → o' ObjectRefContext.∈dom (RuntimeEnv.μ Σ) → ReferenceConsistency Σ Δ' o'
    refConsistency' o' o'Inμ =
      let
        origRefConsistency = refConsistencyFunc o' o'Inμ
        origConnected =  referencesConsistentImpliesConnectivity origRefConsistency
        newConnected = splitReplacementOK {Γ} {Σ} {Δ₀} {o} {o'} {l} {t₁} {t₂} {SplitType.t₁ splT} {SplitType.t₂ splT} {SplitType.t₃ splT}
                                          refl refl consis oLookupUnique (proj₁ origConnected) (proj₂ origConnected) spl
      in 
        referencesConsistent {_} {_} {o'} newConnected
preservation ty@(locTy {Γ} {Δ₀} {T₁ = contractType t₁} {T₂ = contractType t₂} {T₃ = contractType t₃} l spl)
                       consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
                       st@(SElookup {Σ} {l = l} {v = v} _ lookupL) = ?

preservation ty consis st@(SEassertₓ x s) = pres ty consis st {!!} {!!} {!!} {!!}
preservation ty consis st@(SEassertₗ l s) = pres ty consis st {!!} {!!} {!!} {!!}
