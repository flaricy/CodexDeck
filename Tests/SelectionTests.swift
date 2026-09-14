import Foundation
@main struct SelectionTests {
    static func main() throws {
        func candidate(_ id: String,_ at: Double,_ active: Bool=false) -> SessionCandidate {SessionCandidate(id:id,active:active,updatedAt:at)}
        var state=SessionSelection()
        state.reconcile([candidate("current",10,true),candidate("old",9),candidate("older",8)])
        precondition(state.selected == ["current"],"History must not fill a single active key")
        state.reconcile([candidate("new",11,true),candidate("current",10,true),candidate("old",9)])
        precondition(state.selected == ["current","new"],"New sessions append without swapping keys")
        state.hide("current")
        state.reconcile([candidate("new",11,true),candidate("current",10),candidate("old",9)])
        precondition(state.selected == ["new"],"Hiding must not backfill history")
        state.hide("new")
        state.reconcile([candidate("new",12,true),candidate("current",10),candidate("old",9)])
        precondition(state.selected.isEmpty,"Hidden sessions stay hidden even after updates")
        var restored=try JSONDecoder().decode(SessionSelection.self,from:JSONEncoder().encode(state))
        restored.reconcile([candidate("new",12,true),candidate("current",10),candidate("old",9)])
        precondition(restored.selected.isEmpty,"Hidden choice survives persistence")
        restored.show("new");precondition(restored.selected == ["new"])
        restored.reconcile([candidate("fresh",13,true),candidate("new",12,true),candidate("old",9),candidate("ancient",1)])
        precondition(restored.selected == ["new","fresh"],"An older newly fetched history row must not become a key")
        restored.reconcile([candidate("next",14,true),candidate("fresh",13,true),candidate("new",12,true),candidate("extra",14,true)])
        precondition(restored.selected.count == 3)
        var idle=SessionSelection();idle.reconcile([candidate("latest",10),candidate("old",9)])
        precondition(idle.selected == ["latest"],"Initial idle history should show only the latest session")
        idle.reconcile([candidate("old",11,true),candidate("latest",10)])
        precondition(idle.selected == ["latest","old"],"A resumed known session should join the deck")
        print("PASS: 10 selection checks (1–3 keys, hide, restore, persistence, new and resumed sessions)")
    }
}
