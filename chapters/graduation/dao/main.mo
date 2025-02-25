import Result "mo:base/Result";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Types "types";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Option "mo:base/Option";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Int "mo:base/Int";

actor DAO {

        type Result<A, B> = Result.Result<A, B>;
        type Member = Types.Member;
        type ProposalContent = Types.ProposalContent;
        type ProposalId = Types.ProposalId;
        type Proposal = Types.Proposal;
        type Vote = Types.Vote;
        type HttpRequest = Types.HttpRequest;
        type HttpResponse = Types.HttpResponse;

        // The principal of the Webpage canister associated with this DAO canister (needs to be updated with the ID of your Webpage canister)
        stable let canisterIdWebpage : Principal = Principal.fromText("6ldcj-gyaaa-aaaab-qacsa-cai");
        stable var manifesto = "Empower the next generation of builders and make the DAO-revolution";
        stable let name = "Motoko Bootcamp DAO";
        stable var goals : [Text] = [];
        type TokenCanister = actor {
        burn: (Principal, Nat) -> async Result<(), Text>; 
        balanceOf: (Principal) -> async Nat; // Get the token balance of a user
        mint: (Principal, Nat) -> async Result<(), Text>; 
        };
        // let tokenCanister: TokenCanister = actor "bd3sg-teaaa-aaaaa-qaaba-cai"; // replace with actual principal ID
        let tokenCanister: TokenCanister = actor "jaamb-mqaaa-aaaaj-qa3ka-cai";

        // Returns the name of the DAO
        public query func getName() : async Text {
                return name;
        };

        // Returns the manifesto of the DAO
        public query func getManifesto() : async Text {
                return manifesto;
        };

        // Returns the goals of the DAO
        public shared query func getGoals() : async [Text] {
                return goals;
    };

        // Register a new member in the DAO with the given name and principal of the caller
        // Airdrop 10 MBC tokens to the new member
        // New members are always Student
        // Returns an error if the member already exists
        let members = HashMap.HashMap<Principal, Member>(0, Principal.equal, Principal.hash);

        // let ledger = HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);

        // Initial setup of Mentor
        let mentor = Principal.fromText("nkqop-siaaa-aaaaj-qa3qq-cai");
        let newMember : Member = {
        name = "motoko_bootcamp";
        role = #Mentor;
        };
        members.put(mentor, newMember);

        let mentor2 = Principal.fromText("2vxsx-fae");
        let newMember2 : Member = {
        name = "nicole";
        role = #Mentor;
        };
        members.put(mentor2, newMember2);

        public shared ({ caller }) func registerMember(name : Text) : async Result<(), Text> {
                switch (members.get(caller)) {
            case (null) {
                let newMember : Member = {
                        name;
                        role = #Student;
                };
                members.put(caller, newMember);
                let _ = await tokenCanister.mint(caller, 10);
                return #ok();
            };
            case (?member) {
                return #err("Member already exists");
            };
        };
        };

        // Get the member with the given principal
        // Returns an error if the member does not exist
        public query func getMember(p : Principal) : async Result<Member, Text> {
                switch (members.get(p)) {
            case (null) {
                return #err("Member does not exist");
            };
            case (?member) {
                return #ok(member);
            };
        };
        };

        public query func getAllMembers() : async [Member] {
        return Iter.toArray(members.vals());
    };
        // Graduate the student with the given principal
        // Returns an error if the student does not exist or is not a student
        // Returns an error if the caller is not a mentor
        public shared ({ caller }) func graduate(student : Principal) : async Result<(), Text> {
                switch (members.get(caller)) {
                        case (null) {
                                return #err("Caller is not a member");
                        };
                        case (?member) {
                                if (member.role != #Mentor) {
                                        return #err("Caller is not a mentor");
                                };
                        }
                };
                switch (members.get(student)) {
                        case (null) {
                                return #err("Student does not exist");
                        };
                        case (?member) {
                                if (member.role != #Student) {
                                        return #err("Member is not a student");
                                }
                                else {
                                        members.put(student, { name = member.name; role = #Graduate });
                                        return #ok();
                                };
                        }
                }
        };

        // Create a new proposal and returns its id
        // Returns an error if the caller is not a mentor or doesn't own at least 1 MBC token
        var nextProposalId : Nat = 0;

       // Simple hash function for Nat
        func natHash(n : Nat) : Nat32 {
                return Nat32.fromNat(n) % 0x3fffffff; // Simple modulo to fit Nat into Nat32 with a large prime
        };
        let proposals = HashMap.HashMap<ProposalId, Proposal>(0, Nat.equal, natHash);
        public shared ({ caller }) func createProposal(content : ProposalContent) : async Result<ProposalId, Text> {
                switch (members.get(caller)) {
                        case (null) {
                                return #err("Caller is not a member");
                        };
                        case (?member) {
                                if (member.role != #Mentor) {
                                        return #err("Caller is not a mentor, cannot create a proposal");
                                };
                                let balance = await tokenCanister.balanceOf(caller);
                                if (balance < 1) {
                                        return #err("The caller does not have enough tokens to create a proposal");
                                        };
                                let id = nextProposalId;
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
                            let burnResult = await tokenCanister.burn(caller, 1);
                            switch (burnResult) {
                                case(#ok(_)){

                                        proposals.put(nextProposalId, proposal);
                                        nextProposalId += 1;
                                        return #ok(1);
                                };
                                case(#err(_)) {
                                    return #err("Error burning tokens");
                                };
                            };
                            
                            return #ok(nextProposalId - 1);
                        };
                };
        };

        // Get the proposal with the given id
        // Returns an error if the proposal does not exist
        public query func getProposal(id : ProposalId) : async Result<Proposal, Text> {
                switch (proposals.get(id)) {
                        case (null) {
                                return #err("Proposal does not exist");
                        };
                        case (?proposal) {
                                return #ok(proposal);
                        };
                };
        };

        // Returns all the proposals
        public query func getAllProposal() : async [Proposal] {
                return Iter.toArray(proposals.vals());
        };

        // Vote for the given proposal
        // Returns an error if the proposal does not exist or the member is not allowed to vote
        public shared ({ caller }) func voteProposal(proposalId : ProposalId, yesOrNo : Bool) : async Result<(), Text> {
                // check if caller is a member
                switch(members.get(caller)) {
                        case (null) {
                                return #err("Caller is not a member");
                        };
                        case (?member) {
                                // check only mentor and graduate can vote
                                if(member.role == #Student) {
                                        return #err("Caller is a student, cannot vote");
                                } else {
                                        // check if proposal exists
                                        switch (proposals.get(proposalId)) {
                                                case (null) {
                                                        return #err("Proposal does not exist");
                                                };
                                                case (?proposal) {
                                                        // check if proposal is open for voting
                                                        if (proposal.status != #Open) {
                                                                return #err("Proposal is not open for voting");
                                                        };
                                                        // check if member has already voted
                                                        if (_hasVoted(proposal, caller)) {
                                                                return #err("The caller has already voted on this proposal");
                                                        };
                                                        let balance = await tokenCanister.balanceOf(caller);
                                                        let multiplierVote = switch (member.role) {
                                                                case (#Mentor) { 
                                                                        switch (yesOrNo) {
                                                                                case (true) { 5 };
                                                                                case (false) { -5 };
                                                                        };
                                                                 };
                                                                case (#Graduate) { 
                                                                        switch (yesOrNo) {
                                                                                case (true) { 1 };
                                                                                case (false) { -1 };
                                                                        };
                                                                 };
                                                                 case (#Student) { 0 };
                                                        };
                                                        let multiplierVotingPower = switch (member.role) {
                                                                case (#Mentor) { 
                                                                        5
                                                                        };
                        
                                                                case (#Graduate) { 
                                                                        1
                                                                        };
                                                               
                                                                 case (#Student) { 0 };
                                                        };
                                                        let newVoteScore = proposal.voteScore + balance * multiplierVote;
                                                        var newExecuted :? Time.Time = null;
                                                        let newVotes = Buffer.fromArray<Vote>(proposal.votes);
                                                        let newVote = {
                                                                member = caller;
                                                                votingPower = balance * multiplierVotingPower;
                                                                yesOrNo = yesOrNo;
                                                        };
                                                        newVotes.add(newVote);
                                                        Debug.print("Vote score: " # Int.toText(newVoteScore));

                                                        let newStatus = if (newVoteScore >= 100) {
                                                                #Accepted
                                                        }
                                                        else if (newVoteScore <= -100) {
                                                                #Rejected
                                                        }
                                                        else {
                                                                #Open
                                                        };
                                                        // Debug.print("New status: " # ProposalStatus.toText(newStatus));
                                                        Debug.print("New vote scores: " # Int.toText(newVotes.size()));
                                                        // check if proposal is accepted or rejected
                                                        switch (newStatus) {
                                                                case (#Accepted) {
                                                                        let executionResult = _executeProposal(proposal.content);
                                                                        newExecuted := ?Time.now();
                                                                        // return #ok();
                                                                };
                                                                case (_) {}
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
                                                };
                                        };
                                };
                };
        };
        
        // Returns the Principal ID of the Webpage canister associated with this DAO canister
        public shared func getIdWebpage() : async Principal {
                return canisterIdWebpage;
        };

        // helper functions 

        func _executeProposal(content : ProposalContent) : Result<(), Text> {
                switch (content) {
                        case (#ChangeManifesto(newManifesto)) {
                                manifesto := newManifesto;
                                };
                        case (#AddGoal(newGoal)) {
                        let buffer = Buffer.fromArray<Text>(goals);
                        buffer.add(newGoal);
                        goals := Buffer.toArray(buffer);
                                };
                        case (#AddMentor(newMentor)) {
                                switch (members.get(newMentor)) {
                                        case (null) {
                                                return #err("Mentor does not exist");
                                                };
                                        case (?member) {
                                                if (member.role == #Graduate) {
                                                        members.put(newMentor, { name = member.name; role = #Mentor });
                                                        };
                                                };
                                        };
                                };
                        };
        return #ok();
        };

        func _hasVoted (proposal : Proposal, member : Principal) : Bool {
                return Array.find<Vote>(
                proposal.votes,
                func(vote : Vote) {
                return vote.member == member;
                }
                ) != null;
        };

};