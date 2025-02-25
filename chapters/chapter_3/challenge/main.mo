import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Result "mo:base/Result";
import Types "types";

actor TokenContract {

  type Result<Ok, Err> = Types.Result<Ok, Err>;

  // La variable ledger associe à chaque utilisateur (Principal) son solde (Nat).
  let ledger : HashMap.HashMap<Principal, Nat> =
    HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);

  // Renvoie le nom de votre token.
  public query func tokenName() : async Text {
    return "Motoko Bootcamp Token";
  };

  // Renvoie le symbole du token (3 caractères exactement).
  public query func tokenSymbol() : async Text {
    return "MBT";
  };

  // Ajoute le montant spécifié au solde du propriétaire.
  public func mint(owner: Principal, amount: Nat) : async Result<(), Text> {
    let currentBalance = Option.get(ledger.get(owner), 0);
    ledger.put(owner, currentBalance + amount);
    return #ok();
  };

  // Retire le montant spécifié du solde du propriétaire, après vérification.
  public func burn(owner: Principal, amount: Nat) : async Result<(), Text> {
    let currentBalance = Option.get(ledger.get(owner), 0);
    if (currentBalance < amount) {
      return #err("Solde insuffisant pour brûler");
    };
    ledger.put(owner, currentBalance - amount);
    return #ok();
  };

  // Transfère le montant de tokens du compte 'from' vers le compte 'to'.
  // L’opération n’est autorisée que si l’appelant est le détenteur des tokens.
  public shared ({ caller }) func transfer(from: Principal, to: Principal, amount: Nat) : async Result<(), Text> {
    if (caller != from) {
      return #err("Transfert non autorisé");
    };
    let senderBalance = Option.get(ledger.get(from), 0);
    if (senderBalance < amount) {
      return #err("Solde insuffisant pour le transfert");
    };
    // Mise à jour des soldes
    ledger.put(from, senderBalance - amount);
    let recipientBalance = Option.get(ledger.get(to), 0);
    ledger.put(to, recipientBalance + amount);
    return #ok();
  };

  // Renvoie le solde du compte spécifié. Retourne 0 si le compte n'existe pas.
  public query func balanceOf(owner: Principal) : async Nat {
    return Option.get(ledger.get(owner), 0);
  };

  // Calcule l’offre totale de tokens en additionnant tous les soldes présents dans le ledger.
  public query func totalSupply() : async Nat {
    var total: Nat = 0;
    for (bal in ledger.vals()) {
      total += bal;
    };
    return total;
  };
};
