;; Homeschool Assessment Coordinator Contract
;; Manages assessment scheduling, performance tracking, and portfolio development

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-ASSESSMENT-NOT-FOUND (err u401))
(define-constant ERR-STUDENT-NOT-FOUND (err u402))
(define-constant ERR-INVALID-DATE (err u403))
(define-constant ERR-INVALID-SCORE (err u404))
(define-constant ERR-ALREADY-SCHEDULED (err u405))
(define-constant ERR-ASSESSMENT-COMPLETED (err u406))
(define-constant ERR-PORTFOLIO-NOT-FOUND (err u407))
(define-constant ERR-INVALID-ASSESSMENT-TYPE (err u408))
(define-constant ERR-PREPARATION-NOT-FOUND (err u409))
(define-constant ERR-INVALID-GRADE_LEVEL (err u410))

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-assessment-id uint u1)
(define-data-var next-portfolio-id uint u1)
(define-data-var next-preparation-id uint u1)
(define-data-var current-testing-season (string-ascii 20) "SPRING_2024")

;; Assessment types
(define-constant VALID-ASSESSMENT-TYPES (list
  "STANDARDIZED_TEST" "PORTFOLIO_REVIEW" "COMPETENCY_EXAM"
  "SUBJECT_ASSESSMENT" "ANNUAL_EVALUATION" "DIAGNOSTIC_TEST"
  "PROGRESS_ASSESSMENT" "FINAL_EXAM"
))

;; Assessment definitions and scheduling
(define-map assessments
  { assessment-id: uint }
  {
    title: (string-ascii 200),
    description: (string-ascii 500),
    assessment-type: (string-ascii 50),
    subject: (string-ascii 50),
    grade-levels: (list 12 uint),
    duration-minutes: uint,
    max-score: uint,
    passing-score: uint,
    created-by: principal,
    created-at: uint,
    active: bool
  }
)

;; Student assessment schedules
(define-map assessment-schedules
  { student-id: uint, assessment-id: uint }
  {
    scheduled-date: uint,
    scheduled-time: uint,
    location: (optional (string-ascii 200)),
    proctor: (optional principal),
    status: (string-ascii 20),
    scheduled-by: principal,
    scheduled-at: uint,
    notes: (optional (string-ascii 500))
  }
)

;; Assessment results and scores
(define-map assessment-results
  { student-id: uint, assessment-id: uint }
  {
    score: uint,
    max-possible: uint,
    percentage: uint,
    passed: bool,
    completion-date: uint,
    time-taken-minutes: uint,
    graded-by: principal,
    feedback: (optional (string-ascii 1000)),
    verified: bool
  }
)

;; Student portfolios
(define-map student-portfolios
  { portfolio-id: uint }
  {
    student-id: uint,
    title: (string-ascii 200),
    description: (string-ascii 500),
    grade-level: uint,
    school-year: uint,
    subjects-covered: (list 10 (string-ascii 50)),
    artifacts: (list 50 (string-ascii 100)),
    created-by: principal,
    created-at: uint,
    last-updated: uint,
    status: (string-ascii 20),
    reviewed: bool
  }
)

;; Portfolio artifacts (work samples, projects, etc.)
(define-map portfolio-artifacts
  { portfolio-id: uint, artifact-index: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    subject: (string-ascii 50),
    artifact-type: (string-ascii 50),
    file-hash: (string-ascii 64),
    completion-date: uint,
    grade-received: (optional (string-ascii 10)),
    reflection: (optional (string-ascii 500))
  }
)

;; Test preparation tracking
(define-map test-preparation
  { preparation-id: uint }
  {
    student-id: uint,
    test-name: (string-ascii 100),
    target-date: uint,
    preparation-start: uint,
    study-plan: (string-ascii 1000),
    resources-used: (list 20 (string-ascii 100)),
    practice-scores: (list 10 uint),
    readiness-level: uint,
    created-by: principal,
    last-updated: uint
  }
)

;; Performance analytics and trends
(define-map student-performance
  { student-id: uint, subject: (string-ascii 50) }
  {
    total-assessments: uint,
    average-score: uint,
    highest-score: uint,
    lowest-score: uint,
    improvement-trend: (string-ascii 20),
    last-assessment: uint,
    strengths: (list 5 (string-ascii 100)),
    areas-for-improvement: (list 5 (string-ascii 100))
  }
)

;; Assessment accommodations
(define-map student-accommodations
  { student-id: uint }
  {
    extended-time: bool,
    extra-time-percentage: uint,
    separate-room: bool,
    read-aloud: bool,
    large-print: bool,
    assistive-technology: bool,
    frequent-breaks: bool,
    other-accommodations: (optional (string-ascii 500)),
    approved-by: principal,
    approved-at: uint
  }
)

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-student-parent (student-id uint))
  ;; This would typically check against the curriculum-tracker contract
  ;; For now, we'll use a simplified check
  true
)

(define-private (is-valid-assessment-type (assessment-type (string-ascii 50)))
  ;; Cast assessment-type to match the list element type for proper comparison
  (is-some (index-of VALID-ASSESSMENT-TYPES (unwrap-panic (as-max-len? assessment-type u19))))
)

(define-private (calculate-percentage (score uint) (max-score uint))
  (if (> max-score u0)
    (/ (* score u100) max-score)
    u0
  )
)

(define-private (update-performance-stats (student-id uint) (subject (string-ascii 50)) (score uint) (max-score uint))
  (let
    (
      (percentage (calculate-percentage score max-score))
    )
    (match (map-get? student-performance { student-id: student-id, subject: subject })
      performance
      (let
        (
          (new-total (+ (get total-assessments performance) u1))
          (current-avg (get average-score performance))
          (new-avg (/ (+ (* current-avg (get total-assessments performance)) percentage) new-total))
          (new-highest (if (> percentage (get highest-score performance)) percentage (get highest-score performance)))
          (new-lowest (if (< percentage (get lowest-score performance)) percentage (get lowest-score performance)))
        )
        (map-set student-performance
          { student-id: student-id, subject: subject }
          (merge performance
            {
              total-assessments: new-total,
              average-score: new-avg,
              highest-score: new-highest,
              lowest-score: new-lowest,
              last-assessment: block-height
            }
          )
        )
      )
      (map-set student-performance
        { student-id: student-id, subject: subject }
        {
          total-assessments: u1,
          average-score: percentage,
          highest-score: percentage,
          lowest-score: percentage,
          improvement-trend: "STABLE",
          last-assessment: block-height,
          strengths: (list),
          areas-for-improvement: (list)
        }
      )
    )
  )
)

;; Public functions

;; Create a new assessment
(define-public (create-assessment
  (title (string-ascii 200))
  (description (string-ascii 500))
  (assessment-type (string-ascii 50))
  (subject (string-ascii 50))
  (grade-levels (list 12 uint))
  (duration-minutes uint)
  (max-score uint)
  (passing-score uint)
)
  (let
    (
      (assessment-id (var-get next-assessment-id))
    )
    (asserts! (is-valid-assessment-type assessment-type) ERR-INVALID-ASSESSMENT-TYPE)
    (asserts! (> max-score u0) ERR-INVALID-SCORE)
    (asserts! (<= passing-score max-score) ERR-INVALID-SCORE)
    (asserts! (> duration-minutes u0) ERR-INVALID-DATE)
    (asserts! (> (len grade-levels) u0) ERR-INVALID-GRADE_LEVEL)

    (map-set assessments
      { assessment-id: assessment-id }
      {
        title: title,
        description: description,
        assessment-type: assessment-type,
        subject: subject,
        grade-levels: grade-levels,
        duration-minutes: duration-minutes,
        max-score: max-score,
        passing-score: passing-score,
        created-by: tx-sender,
        created-at: block-height,
        active: true
      }
    )

    (var-set next-assessment-id (+ assessment-id u1))
    (ok assessment-id)
  )
)

;; Schedule assessment for student
(define-public (schedule-assessment
  (student-id uint)
  (assessment-id uint)
  (scheduled-date uint)
  (scheduled-time uint)
  (location (optional (string-ascii 200)))
  (proctor (optional principal))
  (notes (optional (string-ascii 500)))
)
  (let
    (
      (assessment-data (unwrap! (map-get? assessments { assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND))
    )
    (asserts! (is-student-parent student-id) ERR-NOT-AUTHORIZED)
    (asserts! (get active assessment-data) ERR-ASSESSMENT-NOT-FOUND)
    (asserts! (> scheduled-date block-height) ERR-INVALID-DATE)
    (asserts! (is-none (map-get? assessment-schedules { student-id: student-id, assessment-id: assessment-id })) ERR-ALREADY-SCHEDULED)

    (map-set assessment-schedules
      { student-id: student-id, assessment-id: assessment-id }
      {
        scheduled-date: scheduled-date,
        scheduled-time: scheduled-time,
        location: location,
        proctor: proctor,
        status: "SCHEDULED",
        scheduled-by: tx-sender,
        scheduled-at: block-height,
        notes: notes
      }
    )

    (ok true)
  )
)

;; Record assessment results
(define-public (record-assessment-result
  (student-id uint)
  (assessment-id uint)
  (score uint)
  (time-taken-minutes uint)
  (feedback (optional (string-ascii 1000)))
)
  (let
    (
      (assessment-data (unwrap! (map-get? assessments { assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND))
      (schedule-data (unwrap! (map-get? assessment-schedules { student-id: student-id, assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND))
      (max-score (get max-score assessment-data))
      (passing-score (get passing-score assessment-data))
      (percentage (calculate-percentage score max-score))
      (passed (>= score passing-score))
    )
    (asserts! (or (is-student-parent student-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= score max-score) ERR-INVALID-SCORE)
    (asserts! (is-eq (get status schedule-data) "SCHEDULED") ERR-ASSESSMENT-COMPLETED)

    (map-set assessment-results
      { student-id: student-id, assessment-id: assessment-id }
      {
        score: score,
        max-possible: max-score,
        percentage: percentage,
        passed: passed,
        completion-date: block-height,
        time-taken-minutes: time-taken-minutes,
        graded-by: tx-sender,
        feedback: feedback,
        verified: false
      }
    )

    ;; Update schedule status
    (map-set assessment-schedules
      { student-id: student-id, assessment-id: assessment-id }
      (merge schedule-data { status: "COMPLETED" })
    )

    ;; Update performance statistics
    (update-performance-stats student-id (get subject assessment-data) score max-score)

    (ok true)
  )
)

;; Create student portfolio
(define-public (create-portfolio
  (student-id uint)
  (title (string-ascii 200))
  (description (string-ascii 500))
  (grade-level uint)
  (school-year uint)
  (subjects-covered (list 10 (string-ascii 50)))
)
  (let
    (
      (portfolio-id (var-get next-portfolio-id))
    )
    (asserts! (is-student-parent student-id) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= grade-level u1) (<= grade-level u12)) ERR-INVALID-GRADE_LEVEL)
    (asserts! (> (len subjects-covered) u0) ERR-INVALID-ASSESSMENT-TYPE)

    (map-set student-portfolios
      { portfolio-id: portfolio-id }
      {
        student-id: student-id,
        title: title,
        description: description,
        grade-level: grade-level,
        school-year: school-year,
        subjects-covered: subjects-covered,
        artifacts: (list),
        created-by: tx-sender,
        created-at: block-height,
        last-updated: block-height,
        status: "IN_PROGRESS",
        reviewed: false
      }
    )

    (var-set next-portfolio-id (+ portfolio-id u1))
    (ok portfolio-id)
  )
)

;; Add artifact to portfolio
(define-public (add-portfolio-artifact
  (portfolio-id uint)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (subject (string-ascii 50))
  (artifact-type (string-ascii 50))
  (file-hash (string-ascii 64))
  (completion-date uint)
  (grade-received (optional (string-ascii 10)))
  (reflection (optional (string-ascii 500)))
)
  (let
    (
      (portfolio-data (unwrap! (map-get? student-portfolios { portfolio-id: portfolio-id }) ERR-PORTFOLIO-NOT-FOUND))
      (artifact-index (len (get artifacts portfolio-data)))
    )
    (asserts! (is-student-parent (get student-id portfolio-data)) ERR-NOT-AUTHORIZED)
    (asserts! (< artifact-index u50) ERR-INVALID-ASSESSMENT-TYPE) ;; Max 50 artifacts

    (map-set portfolio-artifacts
      { portfolio-id: portfolio-id, artifact-index: artifact-index }
      {
        title: title,
        description: description,
        subject: subject,
        artifact-type: artifact-type,
        file-hash: file-hash,
        completion-date: completion-date,
        grade-received: grade-received,
        reflection: reflection
      }
    )

    ;; Update portfolio with new artifact
    (map-set student-portfolios
      { portfolio-id: portfolio-id }
      (merge portfolio-data
        {
          artifacts: (unwrap! (as-max-len? (append (get artifacts portfolio-data) title) u50) ERR-INVALID-ASSESSMENT-TYPE),
          last-updated: block-height
        }
      )
    )

    (ok artifact-index)
  )
)

;; Start test preparation plan
(define-public (start-test-preparation
  (student-id uint)
  (test-name (string-ascii 100))
  (target-date uint)
  (study-plan (string-ascii 1000))
  (resources-used (list 20 (string-ascii 100)))
)
  (let
    (
      (preparation-id (var-get next-preparation-id))
    )
    (asserts! (is-student-parent student-id) ERR-NOT-AUTHORIZED)
    (asserts! (> target-date block-height) ERR-INVALID-DATE)

    (map-set test-preparation
      { preparation-id: preparation-id }
      {
        student-id: student-id,
        test-name: test-name,
        target-date: target-date,
        preparation-start: block-height,
        study-plan: study-plan,
        resources-used: resources-used,
        practice-scores: (list),
        readiness-level: u0,
        created-by: tx-sender,
        last-updated: block-height
      }
    )

    (var-set next-preparation-id (+ preparation-id u1))
    (ok preparation-id)
  )
)

;; Record practice test score
(define-public (record-practice-score
  (preparation-id uint)
  (score uint)
)
  (let
    (
      (prep-data (unwrap! (map-get? test-preparation { preparation-id: preparation-id }) ERR-PREPARATION-NOT-FOUND))
    )
    (asserts! (is-student-parent (get student-id prep-data)) ERR-NOT-AUTHORIZED)
    (asserts! (<= score u100) ERR-INVALID-SCORE)

    (map-set test-preparation
      { preparation-id: preparation-id }
      (merge prep-data
        {
          practice-scores: (unwrap! (as-max-len? (append (get practice-scores prep-data) score) u10) ERR-INVALID-SCORE),
          readiness-level: score,
          last-updated: block-height
        }
      )
    )

    (ok true)
  )
)

;; Set student accommodations
(define-public (set-accommodations
  (student-id uint)
  (extended-time bool)
  (extra-time-percentage uint)
  (separate-room bool)
  (read-aloud bool)
  (large-print bool)
  (assistive-technology bool)
  (frequent-breaks bool)
  (other-accommodations (optional (string-ascii 500)))
)
  (begin
    (asserts! (or (is-student-parent student-id) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= extra-time-percentage u100) ERR-INVALID-SCORE)

    (map-set student-accommodations
      { student-id: student-id }
      {
        extended-time: extended-time,
        extra-time-percentage: extra-time-percentage,
        separate-room: separate-room,
        read-aloud: read-aloud,
        large-print: large-print,
        assistive-technology: assistive-technology,
        frequent-breaks: frequent-breaks,
        other-accommodations: other-accommodations,
        approved-by: tx-sender,
        approved-at: block-height
      }
    )

    (ok true)
  )
)

;; Read-only functions

;; Get assessment details
(define-read-only (get-assessment (assessment-id uint))
  (map-get? assessments { assessment-id: assessment-id })
)

;; Get assessment schedule
(define-read-only (get-assessment-schedule (student-id uint) (assessment-id uint))
  (map-get? assessment-schedules { student-id: student-id, assessment-id: assessment-id })
)

;; Get assessment results
(define-read-only (get-assessment-results (student-id uint) (assessment-id uint))
  (map-get? assessment-results { student-id: student-id, assessment-id: assessment-id })
)

;; Get student portfolio
(define-read-only (get-portfolio (portfolio-id uint))
  (map-get? student-portfolios { portfolio-id: portfolio-id })
)

;; Get portfolio artifact
(define-read-only (get-portfolio-artifact (portfolio-id uint) (artifact-index uint))
  (map-get? portfolio-artifacts { portfolio-id: portfolio-id, artifact-index: artifact-index })
)

;; Get test preparation plan
(define-read-only (get-test-preparation (preparation-id uint))
  (map-get? test-preparation { preparation-id: preparation-id })
)

;; Get student performance statistics
(define-read-only (get-student-performance (student-id uint) (subject (string-ascii 50)))
  (map-get? student-performance { student-id: student-id, subject: subject })
)

;; Get student accommodations
(define-read-only (get-accommodations (student-id uint))
  (map-get? student-accommodations { student-id: student-id })
)

;; Get comprehensive student assessment overview
(define-read-only (get-student-assessment-overview (student-id uint))
  {
    total-assessments: u0, ;; Would calculate from all subjects
    average-performance: u0, ;; Would calculate overall average
    recent-assessments: (list), ;; Would list recent assessment results
    upcoming-assessments: (list), ;; Would list scheduled assessments
    portfolio-count: u0, ;; Would count student portfolios
    preparation-plans: (list) ;; Would list active preparation plans
  }
)

;; Administrative functions

;; Verify assessment result (admin only)
(define-public (verify-assessment-result (student-id uint) (assessment-id uint))
  (let
    (
      (result-data (unwrap! (map-get? assessment-results { student-id: student-id, assessment-id: assessment-id }) ERR-ASSESSMENT-NOT-FOUND))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)

    (map-set assessment-results
      { student-id: student-id, assessment-id: assessment-id }
      (merge result-data { verified: true })
    )

    (ok true)
  )
)

;; Review portfolio (admin only)
(define-public (review-portfolio (portfolio-id uint) (approved bool))
  (let
    (
      (portfolio-data (unwrap! (map-get? student-portfolios { portfolio-id: portfolio-id }) ERR-PORTFOLIO-NOT-FOUND))
      (new-status (if approved "APPROVED" "NEEDS_REVISION"))
    )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)

    (map-set student-portfolios
      { portfolio-id: portfolio-id }
      (merge portfolio-data
        {
          status: new-status,
          reviewed: true,
          last-updated: block-height
        }
      )
    )

    (ok true)
  )
)

;; Set current testing season (admin only)
(define-public (set-testing-season (season (string-ascii 20)))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set current-testing-season season)
    (ok true)
  )
)

;; Update contract owner
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
