 SUBJECTIVES:
 
 -- 1.	How does the toss decision affect the result of the match? 
 -- (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?
1.Toss win vs match win (core proof)
SELECT
    CASE
        WHEN Toss_Winner = Match_Winner THEN 'Toss Won & Match Won'
        ELSE 'Toss Won but Match Lost'
    END AS Toss_Impact,
    COUNT(*) AS Match_Count
FROM matches
WHERE Outcome_type = 1
GROUP BY Toss_Impact;

2. Impact of toss decision (Bat vs Field)
SELECT
    Toss_Decide,
    COUNT(*) AS Matches,
    SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) AS Toss_Win_Match_Win,
    ROUND(SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) * 100.0 / COUNT(*),2) AS Win_Percentage
FROM matches
WHERE Outcome_type = 1
GROUP BY Toss_Decide;

3. VENUE-WISE PROOF
SELECT
    Venue_Id,
    Toss_Decide,
    COUNT(*) AS Matches,
    ROUND(SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) * 100.0 / COUNT(*),2) AS Win_Percentage
FROM matches
WHERE Outcome_type = 1
GROUP BY Venue_Id, Toss_Decide
ORDER BY Venue_Id, Win_Percentage DESC;


-- 2.	Suggest some of the players who would be best fit for the team.

1.Top Batsmen (Total Runs + Strike Rate)
SELECT p.Player_Name,
SUM(bb.Runs_Scored) AS Total_Runs,
ROUND((SUM(bb.Runs_Scored)/COUNT(bb.Ball_Id))*100,2) AS Strike_Rate
FROM ball_by_ball bb
JOIN matches m ON bb.Match_Id=m.Match_Id
JOIN player p ON bb.Striker=p.Player_Id
WHERE m.Outcome_type=1
GROUP BY p.Player_Name
HAVING COUNT(DISTINCT m.Match_Id)>=20
ORDER BY Total_Runs DESC;


2. Top Bowlers (Total Wickets + Avg Wickets)
SELECT p.Player_Name,
COUNT(wt.Player_Out) AS Total_Wickets,
COUNT(DISTINCT m.Match_Id) AS Matches_Played,
ROUND(COUNT(wt.Player_Out)/COUNT(DISTINCT m.Match_Id),2) AS Avg_Wickets_Per_Match
FROM wicket_taken wt
JOIN ball_by_ball bb
ON wt.Match_Id=bb.Match_Id
AND wt.Innings_No=bb.Innings_No
AND wt.Over_Id=bb.Over_Id
AND wt.Ball_Id=bb.Ball_Id
JOIN matches m
ON bb.Match_Id=m.Match_Id
JOIN player p
ON bb.Bowler=p.Player_Id
WHERE m.Outcome_type=1
AND m.Season_Id BETWEEN 6 AND 9
GROUP BY p.Player_Name
HAVING COUNT(wt.Player_Out)>=30
ORDER BY Total_Wickets DESC;

3. All-Rounders (Bat + Ball Contribution)
SELECT
    p.Player_Name,
    SUM(md.Runs_Scored) AS Total_Runs,
    COUNT(wt.Player_Out) AS Total_Wickets
FROM master_data md
LEFT JOIN wicket_taken wt
    ON md.Match_Id = wt.Match_Id
   AND md.Innings_No = wt.Innings_No
   AND md.Over_Id = wt.Over_Id
   AND md.Ball_Id = wt.Ball_Id
JOIN player p
    ON p.Player_Id IN (md.Striker, md.Bowler)
JOIN (
    SELECT Season_Id
    FROM master_data
    GROUP BY Season_Id
    ORDER BY Season_Id DESC
    LIMIT 4
) s
    ON md.Season_Id = s.Season_Id
GROUP BY p.Player_Id, p.Player_Name
HAVING Total_Runs > 500 AND Total_Wickets > 50
ORDER BY Total_Runs desc, Total_Wickets desc;


-- 3. What are some of the parameters that should be focused on while selecting the players?

1. Bowlers Selection:
SELECT
    p.Player_Name,
    COUNT(bb.Ball_Id) AS Total_Balls_Bowled,
    COUNT(wt.Player_Out) AS Total_Wickets_Taken,
    ROUND(SUM(bb.Runs_Scored)/COUNT(wt.Player_Out),2) AS Bowling_Average,
    ROUND(SUM(bb.Runs_Scored)/(COUNT(bb.Ball_Id)/6),2) AS Economy_Rate,
    ROUND(COUNT(bb.Ball_Id)/COUNT(wt.Player_Out),2) AS Strike_Rate
FROM ball_by_ball bb
LEFT JOIN wicket_taken wt
    ON bb.Match_Id=wt.Match_Id
   AND bb.Innings_No=wt.Innings_No
   AND bb.Over_Id=wt.Over_Id
   AND bb.Ball_Id=wt.Ball_Id
JOIN matches m
    ON bb.Match_Id=m.Match_Id
JOIN player p
    ON bb.Bowler=p.Player_Id
WHERE m.Outcome_type=1
  AND m.Season_Id BETWEEN 6 AND 9
GROUP BY p.Player_Name
HAVING
    COUNT(wt.Player_Out)>30
    AND ROUND(SUM(bb.Runs_Scored)/COUNT(wt.Player_Out),2)<25
    AND ROUND(SUM(bb.Runs_Scored)/(COUNT(bb.Ball_Id)/6),2)<10
    AND ROUND(COUNT(bb.Ball_Id)/COUNT(wt.Player_Out),2)<20
ORDER BY Total_Wickets_Taken DESC;

2. Batsmen Selection:
SELECT
    p.Player_Name,
    SUM(bb.Runs_Scored) AS Total_Runs,
    ROUND(SUM(bb.Runs_Scored)/COUNT(wt.Player_Out),2) AS Batting_Average,
    ROUND((SUM(bb.Runs_Scored)/COUNT(bb.Ball_Id))*100,2) AS Strike_Rate
FROM ball_by_ball bb
LEFT JOIN wicket_taken wt
ON bb.Match_Id=wt.Match_Id
AND bb.Innings_No=wt.Innings_No
AND bb.Over_Id=wt.Over_Id
AND bb.Ball_Id=wt.Ball_Id
JOIN matches m ON bb.Match_Id=m.Match_Id
JOIN player p ON bb.Striker=p.Player_Id
WHERE m.Outcome_type=1
AND m.Season_Id BETWEEN 6 AND 9
GROUP BY p.Player_Name
HAVING
    Total_Runs>1000
    AND Batting_Average>30
    AND Strike_Rate>120
ORDER BY Total_Runs DESC,Batting_Average DESC,Strike_Rate DESC;

3. PowerPlay Performance:
SELECT
    p.Player_Name,
    SUM(bb.Runs_Scored) AS Powerplay_Runs,
    ROUND((SUM(bb.Runs_Scored)/COUNT(bb.Ball_Id))*100,2) AS Powerplay_Strike_Rate,
    COUNT(wt.Player_Out) AS Powerplay_Wickets,
    ROUND(SUM(bb.Runs_Scored) /NULLIF((COUNT(bb.Ball_Id)/6),0),2) AS Powerplay_Economy
FROM ball_by_ball bb
LEFT JOIN wicket_taken wt
    ON bb.Match_Id=wt.Match_Id
   AND bb.Innings_No=wt.Innings_No
   AND bb.Over_Id=wt.Over_Id
   AND bb.Ball_Id=wt.Ball_Id
JOIN matches m
    ON bb.Match_Id=m.Match_Id
JOIN player p
    ON p.Player_Id IN (bb.Striker,bb.Bowler)
WHERE m.Outcome_type=1
  AND m.Season_Id BETWEEN 6 AND 9
  AND bb.Over_Id BETWEEN 1 AND 6
GROUP BY p.Player_Id,p.Player_Name
ORDER BY Powerplay_Runs DESC,Powerplay_Wickets DESC;

-- 4.	Which players offer versatility in their skills and can contribute effectively with both bat and ball? 
-- (can you visualize the data for the same)

WITH batting_data AS (
    SELECT
        bb.Striker AS Player_Id,
        p.Player_Name,
        SUM(bb.Runs_Scored) AS Total_Runs_Scored,
        ROUND((SUM(bb.Runs_Scored)/COUNT(bb.Ball_Id))*100,2) AS Batting_Strike_Rate
    FROM ball_by_ball bb
    JOIN matches m ON bb.Match_Id = m.Match_Id
    JOIN player p ON bb.Striker = p.Player_Id
    WHERE m.Outcome_type = 1
      AND m.Season_Id BETWEEN 6 AND 9
    GROUP BY bb.Striker,p.Player_Name
),
bowling_data AS (
    SELECT
        bb.Bowler AS Player_Id,
        p.Player_Name,
        COUNT(wt.Player_Out) AS Total_Wickets_Taken,
        ROUND(COUNT(bb.Ball_Id)/COUNT(wt.Player_Out),2) AS Bowling_Strike_Rate
    FROM ball_by_ball bb
    LEFT JOIN wicket_taken wt
        ON bb.Match_Id = wt.Match_Id
       AND bb.Innings_No = wt.Innings_No
       AND bb.Over_Id = wt.Over_Id
       AND bb.Ball_Id = wt.Ball_Id
    JOIN matches m ON bb.Match_Id = m.Match_Id
    JOIN player p ON bb.Bowler = p.Player_Id
    WHERE m.Outcome_type = 1
      AND m.Season_Id BETWEEN 6 AND 9
    GROUP BY bb.Bowler,p.Player_Name
)
SELECT
    b.Player_Id,
    b.Player_Name,
    b.Total_Runs_Scored,
    b.Batting_Strike_Rate,
    bw.Total_Wickets_Taken,
    bw.Bowling_Strike_Rate
FROM batting_data b
JOIN bowling_data bw
    ON b.Player_Id = bw.Player_Id
WHERE
    b.Batting_Strike_Rate >= 100
    AND bw.Bowling_Strike_Rate <= 40
    AND bw.Total_Wickets_Taken >= 15
ORDER BY b.Total_Runs_Scored DESC,bw.Total_Wickets_Taken DESC
LIMIT 20;

-- 5.	Are there players whose presence positively influences the morale and performance of the team?
-- (justify your answer using visualization)

1. Runs Scored by Players in Winning Matches
SELECT
    p.Player_Name,
    SUM(bb.Runs_Scored) AS Runs_in_Wins,
    COUNT(DISTINCT m.Match_Id) AS Matches_Won
FROM ball_by_ball bb
JOIN matches m ON bb.Match_Id=m.Match_Id
JOIN player p ON bb.Striker=p.Player_Id
WHERE m.Outcome_type=1
GROUP BY p.Player_Name
HAVING Matches_Won>=20
ORDER BY Runs_in_Wins DESC;

2. Man of the Match as a Morale Indicator
SELECT
    p.Player_Name,
    COUNT(m.Man_of_the_Match) AS MOTM_Count
FROM matches m
JOIN player p ON m.Man_of_the_Match=p.Player_Id
GROUP BY p.Player_Name
ORDER BY MOTM_Count DESC;

3. Performance Comparison: Wins vs Losses
SELECT
    p.Player_Name,
    SUM(CASE WHEN m.Outcome_type=1 THEN bb.Runs_Scored ELSE 0 END) AS Runs_in_Wins,
    SUM(CASE WHEN m.Outcome_type<>1 THEN bb.Runs_Scored ELSE 0 END) AS Runs_in_Losses
FROM ball_by_ball bb
JOIN matches m ON bb.Match_Id=m.Match_Id
JOIN player p ON bb.Striker=p.Player_Id
GROUP BY p.Player_Name
HAVING Runs_in_Wins > Runs_in_Losses
ORDER BY Runs_in_Wins DESC
LIMIT 15;

-- 6.	What would you suggest to RCB before going to the mega auction? 

A: Identify RCB Retention Candidates (RCB-specific)
1. High Runs_in_Wins for RCB:
SELECT
    p.Player_Name,
    SUM(bb.Runs_Scored) AS Runs_in_Wins,
    COUNT(DISTINCT m.Match_Id) AS Matches_Won
FROM ball_by_ball bb
JOIN matches m
    ON bb.Match_Id = m.Match_Id
JOIN player p
    ON bb.Striker = p.Player_Id
WHERE
    m.Outcome_type = 1
    AND bb.Team_Batting = (
        SELECT Team_Id
        FROM team
        WHERE Team_Name = 'Royal Challengers Bangalore'
    )
GROUP BY p.Player_Name
HAVING COUNT(DISTINCT m.Match_Id) >= 10
ORDER BY Runs_in_Wins DESC;

2. Man of the Match from RCB:
SELECT
    p.Player_Name,
    COUNT(m.Man_of_the_Match) AS MOTM_Count
FROM matches m
JOIN player p
    ON m.Man_of_the_Match = p.Player_Id
JOIN team t
    ON m.Match_Winner = t.Team_Id
WHERE
    t.Team_Name = 'Royal Challengers Bangalore'
GROUP BY p.Player_Name
ORDER BY MOTM_Count DESC;

3. All-rounder of RCB:
WITH batting_data AS (
    SELECT
        bb.Striker AS Player_Id,
        p.Player_Name,
        SUM(bb.Runs_Scored) AS Total_Runs,
        ROUND((SUM(bb.Runs_Scored)/COUNT(bb.Ball_Id))*100,2) AS Batting_Strike_Rate
    FROM ball_by_ball bb
    JOIN matches m ON bb.Match_Id=m.Match_Id
    JOIN player p ON bb.Striker=p.Player_Id
    WHERE
        m.Outcome_type=1
        AND bb.Team_Batting=(
            SELECT Team_Id FROM team WHERE Team_Name='Royal Challengers Bangalore'
        )
    GROUP BY bb.Striker,p.Player_Name
),
bowling_data AS (
    SELECT
        bb.Bowler AS Player_Id,
        p.Player_Name,
        COUNT(wt.Player_Out) AS Total_Wickets,
        ROUND(COUNT(bb.Ball_Id)/NULLIF(COUNT(wt.Player_Out),0),2) AS Bowling_Strike_Rate
    FROM ball_by_ball bb
    LEFT JOIN wicket_taken wt
        ON bb.Match_Id=wt.Match_Id
       AND bb.Innings_No=wt.Innings_No
       AND bb.Over_Id=wt.Over_Id
       AND bb.Ball_Id=wt.Ball_Id
    JOIN matches m ON bb.Match_Id=m.Match_Id
    JOIN player p ON bb.Bowler=p.Player_Id
    WHERE
        m.Outcome_type=1
        AND bb.Team_Bowling=(SELECT Team_Id FROM team WHERE Team_Name='Royal Challengers Bangalore')
    GROUP BY bb.Bowler,p.Player_Name
)
SELECT
    b.Player_Name,
    b.Total_Runs,
    b.Batting_Strike_Rate,
    bw.Total_Wickets,
    bw.Bowling_Strike_Rate
FROM batting_data b
JOIN bowling_data bw
    ON b.Player_Id=bw.Player_Id
WHERE
    b.Batting_Strike_Rate>=100
    AND bw.Bowling_Strike_Rate<=40
    AND bw.Total_Wickets>=10
ORDER BY b.Total_Runs DESC,bw.Total_Wickets DESC;

B: Identify League-wide High-Impact Players (Auction Targets)
1. Performance in Winning Matches (Impact on Results)
SELECT
    p.Player_Name,
    SUM(bb.Runs_Scored) AS Runs_in_Wins,
    COUNT(DISTINCT m.Match_Id) AS Matches_Won
FROM ball_by_ball bb
JOIN matches m ON bb.Match_Id=m.Match_Id
JOIN player p ON bb.Striker=p.Player_Id
WHERE
    m.Outcome_type=1
    AND bb.Team_Batting <> (
        SELECT Team_Id FROM team WHERE Team_Name='Royal Challengers Bangalore'
    )
GROUP BY p.Player_Name
HAVING COUNT(DISTINCT m.Match_Id)>=20
ORDER BY Runs_in_Wins DESC
limit 10;

2. Impact Difference (Performance Alignment with Wins)
SELECT
    p.Player_Name,
    SUM(CASE WHEN m.Outcome_type=1 THEN bb.Runs_Scored ELSE 0 END) AS Runs_in_Wins,
    SUM(CASE WHEN m.Outcome_type<>1 THEN bb.Runs_Scored ELSE 0 END) AS Runs_in_Losses,
    SUM(CASE WHEN m.Outcome_type=1 THEN bb.Runs_Scored ELSE 0 END)-
    SUM(CASE WHEN m.Outcome_type<>1 THEN bb.Runs_Scored ELSE 0 END) AS Impact_Difference
FROM ball_by_ball bb
JOIN matches m ON bb.Match_Id=m.Match_Id
JOIN player p ON bb.Striker=p.Player_Id
WHERE
    bb.Team_Batting <> (
        SELECT Team_Id FROM team WHERE Team_Name='Royal Challengers Bangalore'
    )
GROUP BY p.Player_Name
HAVING Impact_Difference>0
ORDER BY Impact_Difference DESC
limit 10;


3. Versatility (Genuine All-Rounders)
WITH batting_data AS (
    SELECT
        bb.Striker AS Player_Id,
        p.Player_Name,
        SUM(bb.Runs_Scored) AS Total_Runs,
        ROUND((SUM(bb.Runs_Scored)/COUNT(bb.Ball_Id))*100,2) AS Batting_Strike_Rate
    FROM ball_by_ball bb
    JOIN matches m ON bb.Match_Id=m.Match_Id
    JOIN player p ON bb.Striker=p.Player_Id
    WHERE
        m.Outcome_type=1
        AND bb.Team_Batting <> (
            SELECT Team_Id FROM team WHERE Team_Name='Royal Challengers Bangalore'
        )
    GROUP BY bb.Striker,p.Player_Name
),
bowling_data AS (
    SELECT
        bb.Bowler AS Player_Id,
        p.Player_Name,
        COUNT(wt.Player_Out) AS Total_Wickets,
        ROUND(COUNT(bb.Ball_Id)/NULLIF(COUNT(wt.Player_Out),0),2) AS Bowling_Strike_Rate
    FROM ball_by_ball bb
    LEFT JOIN wicket_taken wt
        ON bb.Match_Id=wt.Match_Id
       AND bb.Innings_No=wt.Innings_No
       AND bb.Over_Id=wt.Over_Id
       AND bb.Ball_Id=wt.Ball_Id
    JOIN matches m ON bb.Match_Id=m.Match_Id
    JOIN player p ON bb.Bowler=p.Player_Id
    WHERE
        m.Outcome_type=1
        AND bb.Team_Bowling <> (
            SELECT Team_Id FROM team WHERE Team_Name='Royal Challengers Bangalore'
        )
    GROUP BY bb.Bowler,p.Player_Name
)
SELECT
    b.Player_Name,
    b.Total_Runs,
    b.Batting_Strike_Rate,
    bw.Total_Wickets,
    bw.Bowling_Strike_Rate
FROM batting_data b
JOIN bowling_data bw
    ON b.Player_Id=bw.Player_Id
WHERE
    b.Batting_Strike_Rate>=100
    AND bw.Bowling_Strike_Rate<=40
    AND bw.Total_Wickets>=15
ORDER BY b.Total_Runs DESC,bw.Total_Wickets DESC
limit 10;

-- 7. What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies?

SELECT
    v.Venue_Name,
    ROUND(SUM(md.Runs_Scored)/COUNT(md.Ball_Id),2) AS Avg_Runs_Per_Ball
FROM master_data md
JOIN matches m ON md.Match_Id=m.Match_Id
JOIN venue v ON m.Venue_Id=v.Venue_Id
GROUP BY v.Venue_Name
ORDER BY Avg_Runs_Per_Ball DESC;

-- 8. Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.

1.Compare RCB performance at Home vs Away
SELECT
    CASE 
        WHEN m.Venue_Id = 1 THEN 'Home'
        ELSE 'Away'
    END AS Match_Location,
    COUNT(*) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = 1 THEN 1 ELSE 0 END) AS Matches_Won,
    ROUND(SUM(CASE WHEN m.Match_Winner = 1 THEN 1 ELSE 0 END)*100.0/COUNT(*),2) AS Win_Percentage
FROM matches m
WHERE 1 IN (m.Team_1,m.Team_2)
GROUP BY Match_Location;

2.Toss + Home Advantage for RCB
SELECT
    m.Toss_Decide,
    COUNT(*) AS Matches,
    SUM(CASE WHEN m.Match_Winner = 2 AND m.Outcome_Type = 1 THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE WHEN m.Outcome_Type = 3 THEN 1 ELSE 0 END) AS Draws,
    SUM(CASE WHEN m.Outcome_Type = 1 AND m.Match_Winner <> 2 THEN 1 ELSE 0 END) AS Losses,
    ROUND(SUM(CASE WHEN m.Match_Winner = 2 AND m.Outcome_Type = 1 THEN 1 ELSE 0 END)*100.0/COUNT(*),2   ) AS Win_Percentage
FROM matches m
WHERE (m.Team_1 = 2 OR m.Team_2 = 2)
AND m.Venue_Id = 1
GROUP BY m.Toss_Decide;

-- 9.Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy.

1.Season-wise Performance Consistency
SELECT
    m.Season_Id,
    COUNT(*) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = 2 AND m.Outcome_Type = 1 THEN 1 ELSE 0 END) AS Matches_Won,
    ROUND(SUM(CASE WHEN m.Match_Winner = 2 AND m.Outcome_Type = 1 THEN 1 ELSE 0 END)*100.0/ COUNT(*),2 ) AS Win_Percentage
FROM matches m
WHERE m.Team_1 = 2 OR m.Team_2 = 2
GROUP BY m.Season_Id
ORDER BY m.Season_Id;

2. Dependence on Few Star Players
SELECT
    p.Player_Name,
    SUM(bb.Runs_Scored) AS Player_Runs,
    ROUND(SUM(bb.Runs_Scored) * 100.0 /SUM(SUM(bb.Runs_Scored)) OVER (),2) AS Contribution_Percentage
FROM ball_by_ball bb
JOIN matches m
    ON bb.Match_Id = m.Match_Id
JOIN player p
    ON bb.Striker = p.Player_Id
WHERE (m.Team_1 = 2 OR m.Team_2 = 2)
GROUP BY p.Player_Id, p.Player_Name
ORDER BY Player_Runs DESC
LIMIT 10;

3.Home-Ground & Toss Strategy Inefficiency
SELECT
    CASE 
        WHEN m.Venue_Id = 1 THEN 'Home'
        ELSE 'Away'
    END AS Match_Location,
    COUNT(*) AS Matches_Played,
    SUM(CASE WHEN m.Match_Winner = 2 AND m.Outcome_Type = 1 THEN 1 ELSE 0 END) AS Matches_Won,
    ROUND(SUM(CASE WHEN m.Match_Winner = 2 AND m.Outcome_Type = 1 THEN 1 ELSE 0 END)*100.0/ COUNT(*),2) AS Win_Percentage
FROM matches m
WHERE (m.Team_1 = 2 OR m.Team_2 = 2)
GROUP BY Match_Location;

-- 11.	In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". 
Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".

SELECT COLUMN_NAME as Matches_Columns
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'matches';

Select * from team;