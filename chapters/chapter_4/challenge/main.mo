import Result "mo:base/Result";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Types "types";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Hash "mo:base/Hash";
import Time "mo:base/Time";
import Array "mo:base/Array";

actor {
  
  /////////////////
  //    TYPES    //
  /////////////////
  type Member = Types.Member;
  type Result<Ok, Err> = Types.Result<Ok, Err>;
  type HashMap<K, V> = Types.HashMap<K, V>;
  type Proposal = Types.Proposal;
  type ProposalContent = Types.ProposalContent;
  type ProposalId = Types.ProposalId;
  type Vote = Types.Vote;

  /////////////////
  // PROJECT #1: DAO INFO & OBJECTIVES
  /////////////////
  let goalsBuffer = Buffer.Buffer<Text>(0);
  let daoName = "Motoko Bootcamp";
  var manifesto = "Empower the next generation of builders and make the DAO-revolution a reality";

  public shared query func getName() : async Text {
    daoName
  };

  public shared query func getManifesto() : async Text {
    manifesto
  };

  public func setManifesto(newManifesto : Text) : async () {
    manifesto := newManifesto;
  };

  public func addGoal(newGoal : Text) : async () {
    goalsBuffer.add(newGoal);
  };

  public shared query func getGoals() : async [Text] {
    Buffer.toArray(goalsBuffer)
  };

  /////////////////
  // PROJECT #2: MEMBERS MANAGEMENT
  /////////////////
  let membersRegistry = HashMap.HashMap<Principal, Member>(0, Principal.equal, Principal.hash);

  public shared ({ caller }) func addMember(member : Member) : async Result<(), Text> {
    switch (membersRegistry.get(caller)) {
      case null {
        membersRegistry.put(caller, member);
        return #ok();
      };
      case (?_) {
        return #err("Member already exists");
      };
    }
  };

  public shared ({ caller }) func updateMember(member : Member) : async Result<(), Text> {
    switch (membersRegistry.get(caller)) {
      case null {
        return #err("Member does not exist");
      };
      case (?_) {
        membersRegistry.put(caller, member);
        return #ok();
      };
    }
  };

  public shared ({ caller }) func removeMember() : async Result<(), Text> {
    switch (membersRegistry.get(caller)) {
      case null {
        return #err("Member does not exist");
      };
      case (?_) {
        membersRegistry.delete(caller);
        return #ok();
      };
    }
  };

  public query func getMember(p : Principal) : async Result<Member, Text> {
    switch (membersRegistry.get(p)) {
      case null {
        return #err("Member does not exist");
      };
      case (?member) {
        return #ok(member);
      };
    }
  };

  public query func getAllMembers() : async [Member] {
    Iter.toArray(membersRegistry.vals())
  };

  public query func numberOfMembers() : async Nat {
    membersRegistry.size()
  };

  /////////////////
  // PROJECT #3: TOKEN SYSTEM
  /////////////////
  let tokenLedger = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);

  public query func tokenName() : async Text {
    "Motoko Bootcamp Token"
  };

  public query func tokenSymbol() : async Text {
    "MBT"
  };

  public func mint(owner : Principal, amount : Nat) : async Result<(), Text> {
    let current = Option.get(tokenLedger.get(owner), 0);
    tokenLedger.put(owner, current + amount);
    return #ok();
  };

  public func burn(owner : Principal, amount : Nat) : async Result<(), Text> {
    let current = Option.get(tokenLedger.get(owner), 0);
    if (current < amount) {
      return #err("Insufficient balance to burn");
    };
    tokenLedger.put(owner, current - amount);
    return #ok();
  };

  // Fonction interne de brûlage (sans vérification préalable)
  func _burn(owner : Principal, amount : Nat) : () {
    let current = Option.get(tokenLedger.get(owner), 0);
    tokenLedger.put(owner, current - amount);
  };

  public shared ({ caller }) func transfer(from : Principal, to : Principal, amount : Nat) : async Result<(), Text> {
    let fromBalance = Option.get(tokenLedger.get(from), 0);
    let toBalance = Option.get(tokenLedger.get(to), 0);
    if (fromBalance < amount) {
      return #err("Insufficient balance to transfer");
    };
    tokenLedger.put(from, fromBalance - amount);
    tokenLedger.put(to, toBalance + amount);
    return #ok();
  };

  public query func balanceOf(owner : Principal) : async Nat {
    Option.get(tokenLedger.get(owner), 0)
  };

  public query func totalSupply() : async Nat {
    var sum = 0;
    for (balance in tokenLedger.vals()) {
      sum += balance;
    };
    sum
  };

  /////////////////
  // PROJECT #4: PROPOSALS & VOTING
  /////////////////
  var nextProposalId : Nat64 = 0;
  let proposals = HashMap.HashMap<ProposalId, Proposal>(0, Nat64.equal, Nat64.toNat32);

  public shared ({ caller }) func createProposal(content : ProposalContent) : async Result<ProposalId, Text> {
    switch (membersRegistry.get(caller)) {
      case null {
        return #err("The caller is not a member - cannot create a proposal");
      };
      case (?_) {
        let balance = Option.get(tokenLedger.get(caller), 0);
        if (balance < 1) {
          return #err("The caller does not have enough tokens to create a proposal");
        };
        // Créer la proposition et brûler les tokens requis
        let proposal : Proposal = {
          id = nextProposalId;
          content;
          creator = caller;
          created = Time.now();
          executed = null;
          votes = [];
          voteScore = 0;
          status = #Open;
        };
        proposals.put(nextProposalId, proposal);
        nextProposalId += 1;
        _burn(caller, 1);
        return #ok(nextProposalId - 1);
      };
    }
  };

  public query func getProposal(proposalId : ProposalId) : async ?Proposal {
    proposals.get(proposalId)
  };

  public shared ({ caller }) func voteProposal(proposalId : ProposalId, vote : Vote) : async Result<(), Text> {
    // Vérifier que l'appelant est membre
    switch (membersRegistry.get(caller)) {
      case null { return #err("The caller is not a member - cannot vote on a proposal"); };
      case (?_) {
        // Vérifier l'existence de la proposition
        switch (proposals.get(proposalId)) {
          case null { return #err("The proposal does not exist"); };
          case (?proposal) {
            // Vérifier que la proposition est ouverte au vote
            if (proposal.status != #Open) {
              return #err("The proposal is not open for voting");
            };
            // Vérifier que l'appelant n'a pas déjà voté
            if (_hasVoted(proposal, caller)) {
              return #err("The caller has already voted on this proposal");
            };
            let balance = Option.get(tokenLedger.get(caller), 0);
            let multiplier = switch (vote.yesOrNo) {
              case (true) { 1 };
              case (false) { -1 };
            };
            let newVoteScore = proposal.voteScore + balance * multiplier;
            var newExecuted : ?Time.Time = null;
            let newVotes = Buffer.fromArray<Vote>(proposal.votes);
            let newStatus = if (newVoteScore >= 100) {
              #Accepted;
            } else if (newVoteScore <= -100) {
              #Rejected;
            } else {
              #Open;
            };
            switch (newStatus) {
              case (#Accepted) {
                _executeProposal(proposal.content);
                newExecuted := ?Time.now();
              };
              case (_) {};
            };
            let newProposal : Proposal = {
              id = proposal.id;
              content = proposal.content;
              creator = proposal.creator;
              created = proposal.created;
              executed = newExecuted;
              votes = Buffer.toArray(newVotes);
              voteScore = newVoteScore;
              status = newStatus;
            };
            proposals.put(proposal.id, newProposal);
            return #ok();
          };
        }
      };
    }
  };

  func _hasVoted(proposal : Proposal, member : Principal) : Bool {
    return Array.find<Vote>(
      proposal.votes,
      func(vote : Vote) {
        return vote.member == member;
      },
    ) != null
  };

  func _executeProposal(content : ProposalContent) : () {
    switch (content) {
      case (#ChangeManifesto(newManifesto)) {
        manifesto := newManifesto;
      };
      case (#AddGoal(newGoal)) {
        goalsBuffer.add(newGoal);
      };
    }
  };

  public query func getAllProposals() : async [Proposal] {
    Iter.toArray(proposals.vals())
  };
}
