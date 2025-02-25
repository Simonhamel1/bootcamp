import Buffer "mo:base/Buffer";

actor {
    // Define an immutable variable for the DAO name
    let nameText : Text = "My DAO";

    // Define a mutable variable for the DAO manifesto
    var manifestoText : Text = "Initial Manifesto";

    // Define a mutable buffer to store the goals of the DAO
    var goals : Buffer.Buffer<Text> = Buffer.Buffer<Text>(10);

    // Implement the getName query function
    public shared query func getName() : async Text {
        return nameText;
    };

    // Implement the getManifesto query function
    public shared query func getManifesto() : async Text {
        return manifestoText;
    };

    // Implement the setManifesto function
    public func setManifesto(newManifesto : Text) : async () {
        manifestoText := newManifesto;
    };

    // Implement the addGoal function
    public func addGoal(newGoal : Text) : async () {
        goals.add(newGoal);
    };

    // Implement the getGoals query function
    public shared query func getGoals() : async [Text] {
        return goals.toArray();
    };
};