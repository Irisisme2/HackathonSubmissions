pragma solidity ^0.8.0;

// Smart Contract for Educational Platform with Interactive Reports, Adaptive Difficulty, and Tokenization using PREDA

// User Structure
struct User {
    bool isTeacher;
    bool isTrainer;
    string name;
    uint256 totalRewards;
    uint256 predaBalance;
    mapping(string => bool) authorizedResources;
    mapping(uint256 => bool) purchasedNFTs;
}

// Achievement Structure as NFT
struct Achievement {
    uint256 tokenId; // Unique token ID
    string name;
    uint256 requiredScore;
    uint256 rewardAmount;
    uint256 tokenValue;
}

// Course Structure
struct Course {
    string courseName;
    address teacher;
    mapping(address => bool) enrolledStudents;
    mapping(uint256 => string) lessons;
    mapping(address => uint256) studentProgress;
    mapping(address => uint256) adaptiveDifficulty;
}

// Report Structure
struct Report {
    address student;
    string courseName;
    uint256 lessonNumber;
    string reportData;
}

// Result Structure
struct Result {
    address student;
    string courseName;
    uint256 lessonNumber;
    string resultData;
    bool verified;
}

// Global Variables
mapping(address => User) public users;
mapping(address => mapping(string => bool)) public teacherCourses;
mapping(string => Course) public courses;
mapping(address => mapping(string => bool)) public studentAchievements;
mapping(uint256 => Achievement) public achievements;
mapping(uint256 => Report) public reports;
mapping(uint256 => Result) public results;
mapping(address => mapping(string => bool)) public purchasedResources;

// Mutex for concurrency control
mapping(string => bool) public mutexForCourse;
mapping(string => bool) public mutexForResource;

// Events
event AchievementUnlocked(address indexed student, string achievementName, uint256 rewardAmount, uint256 tokenValue);
event LessonCompleted(address indexed student, string courseName, uint256 lessonNumber, uint256 newDifficultyLevel);
event InteractiveReportGenerated(address indexed student, string courseName, uint256 lessonNumber, string reportData);
event TokensExchanged(address indexed user, uint256 predaAmount, string benefit);
event ResourcePurchased(address indexed student, string resourceName, uint256 predaAmount);
event ResultSubmitted(address indexed student, string courseName, uint256 lessonNumber, string resultData);
event ResultVerified(address indexed teacher, uint256 resultId);

// Modifiers
modifier onlyTeacher {
    require(users[__transaction.get_sender()].isTeacher, "Only teachers can access this function");
    _;
}

modifier onlyEnrolledStudent(address student, string courseName) {
    require(users[student].enrolledCourses[__transaction.get_sender()], "You are not enrolled in this course");
    _;
}

modifier onlyAuthorizedResource(string resourceName) {
    require(users[__transaction.get_sender()].authorizedResources[resourceName], "You are not authorized to access this resource");
    _;
}

// Smart Contract Functions

// Register User as Student
@address function registerAsStudent(string studentName) export {
    require(!users[__transaction.get_sender()].isTeacher, "You are already registered as a teacher");
    require(!users[__transaction.get_sender()].isTrainer, "You are already registered as a trainer");

    users[__transaction.get_sender()] = User(false, false, studentName, 0, 0);
}

// Register User as Teacher
@address function registerAsTeacher(string teacherName) export {
    require(!users[__transaction.get_sender()].isTeacher, "You are already registered as a teacher");
    require(!users[__transaction.get_sender()].isTrainer, "You are already registered as a trainer");

    users[__transaction.get_sender()] = User(true, false, teacherName, 0, 0);
}

// Register User as Trainer
@address function registerAsTrainer(string trainerName) export {
    require(!users[__transaction.get_sender()].isTeacher, "You are already registered as a teacher");
    require(!users[__transaction.get_sender()].isTrainer, "You are already registered as a trainer");

    users[__transaction.get_sender()] = User(false, true, trainerName, 0, 0);
}

// Add Achievement as NFT
@address function addAchievement(string name, uint256 requiredScore, uint256 rewardAmount, uint256 tokenValue) export onlyTeacher {
    // Increment the NFT token ID
    uint256 tokenId = achievements.length + 1;

    // Create the NFT achievement
    achievements[tokenId] = Achievement(tokenId, name, requiredScore, rewardAmount, tokenValue);
}

// Unlock Achievement as NFT
@address function unlockAchievementNFT(uint256 achievementId) export onlyEnrolledStudent(__transaction.get_sender()) {
    User storage user = users[__transaction.get_sender()];
    require(user.totalRewards >= achievements[achievementId].rewardAmount, "Not enough rewards to unlock this achievement");
    require(user.totalRewards >= achievements[achievementId].requiredScore, "You have not achieved the required score for this achievement");
    require(!user.purchasedNFTs[achievementId], "Achievement already unlocked");

    user.purchasedNFTs[achievementId] = true;
    user.totalRewards -= achievements[achievementId].rewardAmount;
    user.predaBalance += achievements[achievementId].tokenValue;

    emit AchievementUnlocked(__transaction.get_sender(), achievements[achievementId].name, achievements[achievementId].rewardAmount, achievements[achievementId].tokenValue);
}

// Add Course
@address function addCourse(string courseName) export onlyTeacher {
    require(!teacherCourses[__transaction.get_sender()][courseName], "Course with this name already exists");

    Course storage newCourse = courses[courseName];
    newCourse.courseName = courseName;
    newCourse.teacher = __transaction.get_sender();
}

// Enroll Student in Course
@address function enrollStudent(address student, string courseName) export onlyTeacher {
    require(teacherCourses[__transaction.get_sender()][courseName], "You are not the teacher of this course");
    Course storage course = courses[courseName];
    require(!course.enrolledStudents[student], "Student is already enrolled in this course");

    course.enrolledStudents[student] = true;
    users[student].enrolledCourses[__transaction.get_sender()] = true;
}

// Add Lesson to Course
@address function addLesson(string courseName, string lessonContent) export onlyTeacher {
    require(teacherCourses[__transaction.get_sender()][courseName], "You are not the teacher of this course");
    Course storage course = courses[courseName];

    uint256 lessonNumber = course.lessons.length;
    course.lessons[lessonNumber] = lessonContent;
}

// Complete Lesson
@address function completeLesson(string courseName, uint256 lessonNumber) export onlyEnrolledStudent(__transaction.get_sender()) {
    // Dodaj blokadę dostępu do zmiennej 'course'
    require(mutexForCourse[courseName] == false, "Another transaction is modifying the course");
    mutexForCourse[courseName] = true;
    Course storage course = courses[courseName];
    require(lessonNumber < course.lessons.length, "Invalid lesson number");

    // Simulate progress and adjust difficulty based on student's performance
    course.studentProgress[__transaction.get_sender()] += 10;
    if (course.studentProgress[__transaction.get_sender()] >= 50) {
        course.adaptiveDifficulty[__transaction.get_sender()] += 1;
        emit LessonCompleted(__transaction.get_sender(), courseName, lessonNumber, course.adaptiveDifficulty[__transaction.get_sender()]);
    }

    // Generate Interactive Report
    string memory reportData = generateInteractiveReport(courseName, lessonNumber, __transaction.get_sender());
    reports[reports.length] = Report(__transaction.get_sender(), courseName, lessonNumber, reportData);
    emit InteractiveReportGenerated(__transaction.get_sender(), courseName, lessonNumber, reportData);

    // Zwalnianie blokady
    mutexForCourse[courseName] = false;
}

// Get Lesson Content
@address function getLessonContent(string courseName, uint256 lessonNumber) view export onlyAuthorizedResource(courseName) returns (string) {
    Course storage course = courses[courseName];
    require(lessonNumber < course.lessons.length, "Invalid lesson number");

    return course.lessons[lessonNumber];
}

// Authorize Student to Access Resource
@address function authorizeStudent(address student, string resourceName) export onlyTeacher {
    require(users[__transaction.get_sender()].isTeacher, "Only teachers can authorize students");
    users[student].authorizedResources[resourceName] = true;
}

// Generate Interactive Report
@address function generateInteractiveReport(string courseName, uint256 lessonNumber, address student) view export returns (string) {
    // Implement interactive report generation logic here
    return "This is an interactive report for course: " + courseName + ", lesson: " + lessonNumber.toString() + " by student: " + users[student].name;
}

// Exchange Tokens for Benefits
@address function exchangeTokens(uint256 predaAmount, string benefit) export {
    require(users[__transaction.get_sender()].predaBalance >= predaAmount, "Not enough PREDA tokens");

    users[__transaction.get_sender()].predaBalance -= predaAmount;
    // Implement logic to provide benefits based on the exchanged tokens
    emit TokensExchanged(__transaction.get_sender(), predaAmount, benefit);
}

// Purchase Resource with Tokens
@address function purchaseResource(string resourceName, uint256 predaAmount) export onlyEnrolledStudent(__transaction.get_sender(), resourceName) {
    // Dodaj blokadę dostępu do zasobu
    require(mutexForResource[resourceName] == false, "Another transaction is purchasing the resource");
    mutexForResource[resourceName] = true;
    require(!purchasedResources[__transaction.get_sender()][resourceName], "Resource already purchased");
    require(users[__transaction.get_sender()].predaBalance >= predaAmount, "Not enough PREDA tokens");

    // Implement logic to grant access to the purchased resource

    // Mark the resource as purchased
    purchasedResources[__transaction.get_sender()][resourceName] = true;
    users[__transaction.get_sender()].predaBalance -= predaAmount;

    emit ResourcePurchased(__transaction.get_sender(), resourceName, predaAmount);

    // Zwalnianie blokady
    mutexForResource[resourceName] = false;
}

// Submit Results
@address function submitResults(string courseName, uint256 lessonNumber, string resultData) export onlyEnrolledStudent(__transaction.get_sender(), courseName) {
    Course storage course = courses[courseName];
    require(lessonNumber < course.lessons.length, "Invalid lesson number");

    // Save the result on the blockchain
    uint256 resultId = results.length;
    results[resultId] = Result(__transaction.get_sender(), courseName, lessonNumber, resultData, false);

    emit ResultSubmitted(__transaction.get_sender(), courseName, lessonNumber, resultData);
}

// Verify Results (Only Teacher)
@address function verifyResults(uint256 resultId) export onlyTeacher {
    require(resultId < results.length, "Invalid result ID");
    Result storage result = results[resultId];
    require(!result.verified, "Result is already verified");

    // Implement verification logic here

    // Mark the result as verified
    result.verified = true;
    emit ResultVerified(__transaction.get_sender(), resultId);
}
