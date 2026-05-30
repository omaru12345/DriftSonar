public struct CreateProfileRequest {
    public let nickname: String
    public let bio: String
    
    public init(nickname: String, bio: String) {
        self.nickname = nickname
        self.bio = bio
    }
}
