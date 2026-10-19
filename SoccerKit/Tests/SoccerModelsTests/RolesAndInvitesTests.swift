import Foundation
import Testing
@testable import SoccerModels

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

@Suite struct RoleTests {
    @Test func fansOnlyWatch() {
        #expect(Role.fan.canViewScores)
        #expect(!Role.fan.canRunGames)
        #expect(!Role.fan.canManageTeam)
    }

    @Test func adminsRunGamesButDoNotManageTheTeam() {
        #expect(Role.admin.canRunGames)
        #expect(!Role.admin.canManageTeam)
    }

    @Test func ownersCanDoEverything() {
        #expect(Role.owner.canViewScores && Role.owner.canRunGames && Role.owner.canManageTeam)
    }

    @Test func rolesAreOrdered() {
        #expect(Role.fan < Role.admin && Role.admin < Role.owner)
    }
}

@Suite struct InviteCodeTests {
    @Test func generatedCodesUseTheUnambiguousAlphabet() {
        for _ in 0..<200 {
            let code = InviteCode.generate()
            #expect(code.count == InviteCode.length)
            #expect(code.allSatisfy { InviteCode.alphabet.contains($0) })
            #expect(InviteCode.normalize(code) == code)
        }
    }

    @Test(arguments: ["k7qx2m", "K7QX-2M", " K7Q X2M ", "k7q-x2m"])
    func normalizesWhatParentsType(input: String) {
        #expect(InviteCode.normalize(input) == "K7QX2M")
    }

    @Test(arguments: ["", "K7QX2", "K7QX2MM", "K0QX2M", "K7QI2M", "K7QX2!"])
    func rejectsCodesThatCannotExist(input: String) {
        #expect(InviteCode.normalize(input) == nil)
    }

    @Test func joinLinksRoundTrip() {
        let url = InviteCode.joinURL(for: "K7QX2M")
        #expect(url.absoluteString == "https://soccer-live.web.app/join/K7QX2M")
        #expect(InviteCode.code(from: url) == "K7QX2M")
    }

    @Test func ignoresOtherLinks() {
        #expect(InviteCode.code(from: URL(string: "https://example.com/join/K7QX2M")!) == nil)
        #expect(InviteCode.code(from: URL(string: "https://soccer-live.web.app/team/K7QX2M")!) == nil)
        #expect(InviteCode.code(from: URL(string: "https://soccer-live.web.app/join")!) == nil)
    }
}

@Suite struct AdminInviteTests {
    @Test func freshInviteIsRedeemableForAWeek() {
        let invite = AdminInvite.make(teamId: "t1", createdBy: "owner", now: t0)
        #expect(invite.token.count == 32)
        #expect(invite.isRedeemable(at: t0.addingTimeInterval(6 * 24 * 3600)))
        #expect(!invite.isRedeemable(at: t0.addingTimeInterval(7 * 24 * 3600)))
    }

    @Test func usedInviteCannotBeReused() {
        var invite = AdminInvite.make(teamId: "t1", createdBy: "owner", now: t0)
        invite.usedBy = "new-admin"
        #expect(!invite.isRedeemable(at: t0))
    }
}
