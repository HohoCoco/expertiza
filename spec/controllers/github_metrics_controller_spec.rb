 describe GithubMetricsController do
  let(:review_response) { build(:response) }
  let(:assignment) { build(:assignment, id: 1, questionnaires: [review_questionnaire], is_penalty_calculated: true) }
  let(:assignment_questionnaire) { build(:assignment_questionnaire, used_in_round: 1, assignment: assignment) }
  let(:participant) { build(:participant, id: 1, assignment: assignment, user_id: 1) }
  let(:participant2) { build(:participant, id: 2, assignment: assignment, user_id: 1) }
  let(:review_questionnaire) { build(:questionnaire, id: 1, questions: [question]) }
  let(:admin) { build(:admin) }
  let(:instructor) { build(:instructor, id: 6) }
  let(:question) { build(:question) }
  let(:team) { build(:assignment_team, id: 1, assignment: assignment, users: [instructor]) }
  let(:student) { build(:student) }
  let(:review_response_map) { build(:review_response_map, id: 1) }
  let(:assignment_due_date) { build(:assignment_due_date) }

  before(:each) do
    allow(AssignmentParticipant).to receive(:find).with('1').and_return(participant)
    allow(participant).to receive(:team).and_return(team)
    stub_current_user(instructor, instructor.role.name, instructor.role)
    allow(Assignment).to receive(:find).with('1').and_return(assignment)
    allow(Assignment).to receive(:find).with(1).and_return(assignment)

  end

  describe '#view' do
    before(:each) do
      allow(Answer).to receive(:compute_scores).with([review_response], [question]).and_return(max: 95, min: 88, avg: 90)
      allow(Participant).to receive(:where).with(parent_id: 1).and_return([participant])
      allow(AssignmentParticipant).to receive(:find).with(1).and_return(participant)
      allow(assignment).to receive(:late_policy_id).and_return(false)
      allow(assignment).to receive(:calculate_penalty).and_return(false)
      session["github_access_token"] = "QWERTY"
    end

    context 'when user hasn\'t logged in to GitHub' do
      before(:each) do
        @params = {id: 900}
        session["github_access_token"] = nil
      end

      it 'stores the current assignment id and the view action' do
        get :view, @params
        expect(session["assignment_id"]).to eq("900")
        expect(session["github_view_type"]).to eq("view_scores")
      end

      it 'redirects user to GitHub authorization page' do
        get :view, @params
        expect(response).to redirect_to(authorize_github_github_metrics_path)
      end
    end
  end

 describe '#get_statuses_for_pull_request' do
    before(:each) do
      allow(Net::HTTP).to receive(:get) { "{\"team\":\"rails\", \"players\":\"36\"}" }
    end

    it 'makes a call to the GitHub API to get status of the head commit passed' do
      expect(controller.get_statuses_for_pull_request({
                                                          owner: 'expertiza',
                                                          repository: 'expertiza',
                                                          head_commit: 'qwerty123'
                                                      })
      ).to eq("team" => "rails", "players" => "36")
    end
 end

  describe '#retrieve_pull_request_data' do
    before(:each) do

      controller.instance_variable_set(:@gitVariable,:head_refs=> {})
      allow(controller).to receive(:get_pull_request_details).and_return({
                                                                             "data" => {
                                                                                 "repository" => {
                                                                                     "pullRequest" => {
                                                                                         "headRefOid" => "qwerty123"
                                                                                     }
                                                                                 }
                                                                             }
                                                                         })
      allow(controller).to receive(:parse_github_pull_request_data)
    end

    it 'gets pull request details for each PR link submitted' do
      expect(controller).to receive(:get_pull_request_details).with("pull_request_number" => "1261",
                                                                    "repository_name" => "expertiza",
                                                                    "owner_name" => "expertiza")
      expect(controller).to receive(:get_pull_request_details).with("pull_request_number" => "1293",
                                                                    "repository_name" => "mamaMiya",
                                                                    "owner_name" => "Shantanu")
      controller.retrieve_pull_request_data(["https://github.com/expertiza/expertiza/pull/1261",
                                             "https://github.com/Shantanu/mamaMiya/pull/1293"])
    end

    it 'calls parse_github_data_pull on each of the PR details' do
      expect(controller).to receive(:parse_github_pull_request_data).with({"data" => {
          "repository" => {
              "pullRequest" => {
                  "headRefOid" => "qwerty123"
              }
          }
      }}).twice
      controller.retrieve_pull_request_data(["https://github.com/expertiza/expertiza/pull/1261",
                                             "https://github.com/Shantanu/mamaMiya/pull/1293"])
    end
  end

  describe '#retrieve_repository_data' do
    before(:each) do
      allow(controller).to receive(:get_github_repository_details).and_return("pr" => "details")
      allow(controller).to receive(:parse_github_repository_data)
    end

    it 'gets details for each repo link submitted, excluding those for expertiza and servo' do
      expect(controller).to receive(:get_github_repository_details).with("repository_name" => "website",
                                                                         "owner_name" => "Shantanu")
      expect(controller).to receive(:get_github_repository_details).with("repository_name" => "OODD",
                                                                         "owner_name" => "Edward")
      controller.retrieve_repository_data(["https://github.com/Shantanu/website", "https://github.com/Edward/OODD",
                                           "https://github.com/expertiza/expertiza",
                                           "https://github.com/Shantanu/expertiza]"])
    end

    it 'calls parse_github_data_repo on each of the PR details' do
      expect(controller).to receive(:parse_github_repository_data).with("pr" => "details").twice
      controller.retrieve_repository_data(["https://github.com/Shantanu/website", "https://github.com/Edward/OODD"])
    end
  end

  describe '#retrieve_github_data' do
    before(:each) do
      allow(controller).to receive(:retrieve_pull_request_data)
      allow(controller).to receive(:retrieve_repository_data)
    end

    context 'when pull request links have been submitted' do
      before(:each) do
        teams_mock = double
        allow(teams_mock).to receive(:hyperlinks).and_return(["https://github.com/Shantanu/website",
                                                              "https://github.com/Shantanu/website/pull/1123"])
        controller.instance_variable_set(:@team, teams_mock)
      end

      it 'retrieves PR data only' do
        expect(controller).to receive(:retrieve_pull_request_data).with(["https://github.com/Shantanu/website/pull/1123"])
        controller.retrieve_github_data
      end
    end

    context 'when pull request links have not been submitted' do
      before(:each) do
        teams_mock = double
        allow(teams_mock).to receive(:hyperlinks).and_return(["https://github.com/Shantanu/website",
                                                              "https://github.com/expertiza/expertiza"])
        controller.instance_variable_set(:@team, teams_mock)
      end

      it 'retrieves repo details ' do
        expect(controller).to receive(:retrieve_repository_data).with(["https://github.com/Shantanu/website",
                                                                       "https://github.com/expertiza/expertiza"])
        controller.retrieve_github_data
      end
    end
  end

  describe '#retrieve_check_run_statuses' do
    before(:each) do
      allow(controller).to receive(:get_statuses_for_pull_request).and_return("check_status")
      controller.instance_variable_set(:@gitVariable, {
          :head_refs => { "1234" => "qwerty", "5678" => "asdfg"},
          :check_statuses => {}
      })
    end

    it 'gets and stores the statuses associated with head commits of PRs' do
      expect(controller).to receive(:get_statuses_for_pull_request).with("qwerty")
      expect(controller).to receive(:get_statuses_for_pull_request).with("asdfg")
      controller.retrieve_pull_request_statuses_data
      expect(controller.instance_variable_get(:@gitVariable)[:check_statuses]).to eq("1234" => "check_status",
                                                                       "5678" => "check_status")
    end
  end

  describe '#view_github_metrics' do
    context 'when user hasn\'t logged in to GitHub' do
      before(:each) do
        @params = {id: 900}
        session["github_access_token"] = nil
      end

      it 'stores the current participant id and the view action' do
        get :view_github_metrics, @params
        expect(session["participant_id"]).to eq("900")
        expect(session["github_view_type"]).to eq("view_submissions")
      end

      it 'redirects user to GitHub authorization page' do
        get :view_github_metrics, @params
        expect(response).to redirect_to(authorize_github_github_metrics_path)
      end
    end

    context 'when user has logged in to GitHub' do
      before(:each) do
        session["github_access_token"] = "qwerty"
        allow(controller).to receive(:get_statuses_for_pull_request).and_return("status")
        allow(controller).to receive(:retrieve_github_data)
        allow(controller).to receive(:retrieve_pull_request_statuses_data)
      end

      it 'stores the GitHub access token for later use' do
        get :view_github_metrics, id: '1'
        expect(controller.instance_variable_get(:@token)).to eq("qwerty")
      end

      it 'calls retrieve_github_data to retrieve data from GitHub' do
        expect(controller).to receive(:retrieve_github_data)
        get :view_github_metrics, id: '1'
      end

      it 'calls retrieve_check_run_statuses to retrieve check runs data' do
        expect(controller).to receive(:retrieve_pull_request_statuses_data)
        get :view_github_metrics, id: '1'
      end
    end
  end

  describe '#authorize_github' do
    it 'redirects the user to GitHub authorization page' do
      get :authorize_github
      expect(response).to redirect_to("https://github.com/login/oauth/authorize?client_id=qwerty12345")
    end
  end

  describe '#get_github_repository_details' do
    before(:each) do
      allow(controller).to receive(:make_github_graphql_request).and_return("github": "github")
    end

    it 'gets  make_github_graphql_request with query for repository' do
      hyperlink_data = {
        "owner_name" => "Shantanu",
        "repository_name" => "expertiza"
      }

      expect(controller).to receive(:make_github_graphql_request).with(
        query:       "query {
        repository(owner: \"" + hyperlink_data["owner_name"] + "\", name: \"" + hyperlink_data["repository_name"] + "\") {
          ref(qualifiedName: \"master\") {
            target {
              ... on Commit {
                id
                  history(first: 100) {
                    edges {
                      node {
                        id author {
                          name email date
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }"
      )
      details = controller.get_github_repository_details(hyperlink_data)
      expect(details).to eq("github": "github")
    end
  end

  describe '#get_pull_request_details' do
    before(:each) do
      allow(controller).to receive(:get_query_for_pull_request_links)
      allow(controller).to receive(:make_github_graphql_request).and_return(
        "data" => {
          "repository" => {
            "pullRequest" => {
              "commits" => {
                "edges" => [],
                "pageInfo" => {
                  "hasNextPage" => false,
                  "endCursor" => "qwerty"
                }
              }
            }
          }
        }
      )
    end

    it 'gets pull request data for link passed' do
      data = controller.get_pull_request_details("https://github.com/expertiza/expertiza")
      expect(data).to eq(
        "data" => {
          "repository" => {
            "pullRequest" => {
              "commits" => {
                "edges" => [],
                "pageInfo" => {
                  "hasNextPage" => false,
                  "endCursor" => "qwerty"
                }
              }
            }
          }
        }
      )
    end
  end

  describe '#process_github_authors_and_dates' do
    before(:each) do

      controller.instance_variable_set(
        :@gitVariable, {
        :authors=> {},
        :dates=> {},
        :parsed_data=> {}
        }
      )
    end
    it 'sets authors and data for GitHub data' do
      controller.process_github_authors_and_dates("author", "date")
      expect(controller.instance_variable_get(:@gitVariable)[:authors]).to eq("author" => 1)
      expect(controller.instance_variable_get(:@gitVariable)[:dates]).to eq("date" => 1)
      expect(controller.instance_variable_get(:@gitVariable)[:parsed_data]).to eq("author" => {"date" => 1})

      controller.process_github_authors_and_dates("author", "date")
      expect(controller.instance_variable_get(:@gitVariable)[:parsed_data]).to eq( "author" => {"date" => 2})
    end
  end

  describe '#parse_github_pull_request_data' do
    before(:each) do
      allow(controller).to receive(:process_github_authors_and_dates)
      allow(controller).to receive(:get_team_github_statistics)
      allow(controller).to receive(:organize_commit_dates_in_sorted_order)
      @github_data = {
        "data" => {
          "repository" => {
            "pullRequest" => {
              "commits" => {
                "edges" => [
                  {
                    "node" => {
                      "commit" => {
                        "author" => {
                          "name" => "Shantanu"
                        },
                        "committedDate" => "2018-12-1013:45"
                      }
                    }
                  }
                ]
              }
            }
          }
        }
      }
    end

    it 'calls team_statistics' do
      expect(controller).to receive(:get_team_github_statistics).with(@github_data)
      controller.parse_github_pull_request_data(@github_data)
    end

    it 'calls process_github_authors_and_dates for each commit object of GitHub data passed in' do
      expect(controller).to receive(:process_github_authors_and_dates).with("Shantanu", "2018-12-10")
      controller.parse_github_pull_request_data(@github_data)
    end

    it 'calls organize_commit_dates' do
      expect(controller).to receive(:organize_commit_dates_in_sorted_order)
      controller.parse_github_pull_request_data(@github_data)
    end
  end

  describe '#parse_github_repository_data' do
    before(:each) do
      allow(controller).to receive(:process_github_authors_and_dates)
      allow(controller).to receive(:organize_commit_dates_in_sorted_order)
      @github_data = {
        "data" => {
          "repository" => {
            "ref" => {
              "target" => {
                "history" => {
                  "edges" => [
                    {
                      "node" => {
                        "author" => {
                          "name" => "Shantanu",
                          "date" => "2018-12-1013:45"
                        }
                      }
                    }
                  ]
                }
              }
            }
          }
        }
      }
    end

    it 'calls process_github_authors_and_dates for each commit object of GitHub data passed in' do
      expect(controller).to receive(:process_github_authors_and_dates).with("Shantanu", "2018-12-10")
      controller.parse_github_repository_data(@github_data)
    end

    it 'calls organize_commit_dates' do
      expect(controller).to receive(:organize_commit_dates_in_sorted_order)
      controller.parse_github_repository_data(@github_data)
    end
  end

  describe '#make_github_graphql_request' do
    before(:each) do
      session['github_access_token'] = "qwerty"
    end

    it 'gets data from GitHub api v4(graphql)' do
      response = controller.make_github_graphql_request("{\"team\":\"rails\",\"players\":\"36\"}")
      expect(response).to eq("message" => "Bad credentials", "documentation_url" => "https://developer.github.com/v4")
    end
  end

  describe 'get_query' do
    before(:each) do
      controller.instance_variable_set(:@end_cursor, "")
    end
    it 'constructs the graphql query' do
      query = {
        query:   "query {
        repository(owner: \"expertiza\", name:\"expertiza\") {
          pullRequest(number: 1228) {
            number additions deletions changedFiles mergeable merged headRefOid
              commits(first:100, after:){
                totalCount
                  pageInfo{
                    hasNextPage startCursor endCursor
                    }
                      edges{
                        node{
                          id  commit{
                                author{
                                  name
                                }
                               additions deletions changedFiles committedDate
                        }}}}}}}"
      }
      hyperlink_data = {}
      hyperlink_data["owner_name"] = "expertiza"
      hyperlink_data["repository_name"] = "expertiza"
      hyperlink_data["pull_request_number"] = "1228"
      response = controller.get_query_for_pull_request_links(hyperlink_data)
      expect(response).to eq(query)
    end
  end

  describe '#team_statistics' do
    before(:each) do
      controller.instance_variable_set(:@gitVariable,
          {
          :total_additions => 0,
          :total_deletions => 0,
          :total_commits => 0,
          :total_files_changed => 0,
          :head_refs=>[],
          :merge_status=> []
          }
      )

    end

    it 'parses team data from github data for merged pull Request' do
      controller.get_team_github_statistics(
        "data" => {
          "repository" => {
            "pullRequest" => {
              "number" => 8,
              "additions" => 2,
              "deletions" => 1,
              "changedFiles" => 3,
              "mergeable" => "UNKNOWN",
              "merged" => true,
              "headRefOid" => "123abc",
              "commits" => {
                "totalCount" => 16,
                "pageInfo" => {},
                "edges" => []
              }
            }
          }
        }
      )
      expect(controller.instance_variable_get(:@gitVariable)[:total_additions]).to eq(2)
      expect(controller.instance_variable_get(:@gitVariable)[:total_deletions]).to eq(1)
      expect(controller.instance_variable_get(:@gitVariable)[:total_files_changed]).to eq(3)
      expect(controller.instance_variable_get(:@gitVariable)[:total_commits]).to eq(16)
      expect(controller.instance_variable_get(:@gitVariable)[:merge_status][8]).to eq("MERGED")
    end

    it 'parses team data from github data for non-merged pull Request' do
      controller.get_team_github_statistics(
          "data" => {
              "repository" => {
                  "pullRequest" => {
                     "number" => 8,
                     "additions" => 2,
                     "deletions" => 1,
                     "changedFiles" => 3,
                     "mergeable" => true,
                     "merged" => false,
                     "headRefOid" => "123abc",
                     "commits" => {
                          "totalCount" => 16,
                          "pageInfo" => {},
                          "edges" => []
                      }
                  }
              }
          }
      )
      expect(controller.instance_variable_get(:@gitVariable)[:total_additions]).to eq(2)
      expect(controller.instance_variable_get(:@gitVariable)[:total_deletions]).to eq(1)
      expect(controller.instance_variable_get(:@gitVariable)[:total_files_changed]).to eq(3)
      expect(controller.instance_variable_get(:@gitVariable)[:total_commits]).to eq(16)
      expect(controller.instance_variable_get(:@gitVariable)[:merge_status][8]).to eq(true)
    end
  end

  describe '#organize_commit_dates' do
    before(:each) do

      controller.instance_variable_set(:@gitVariable, {
          :dates => {"2017-04-05" => 1, "2017-04-13" => 1, "2017-04-14" => 1},
          :parsed_data => {"abc" => {"2017-04-14" => 2, "2017-04-13" => 2, "2017-04-05" => 2}}
      })
    end

    it 'calls organize_commit_dates to sort parsed commits by dates' do
      controller.organize_commit_dates_in_sorted_order
      expect(controller.instance_variable_get(:@gitVariable)[:parsed_data]).to eq({"abc" => {"2017-04-05" => 2, "2017-04-13" => 2,
                                                                              "2017-04-14" => 2}})
    end
  end
end
