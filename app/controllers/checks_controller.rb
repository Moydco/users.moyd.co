class ChecksController < ApplicationController
  # nothing than a default page
  def index
    if signed_in?
      @user ||= User.find(current_user["_id"]["$oid"])
      if @user.is_admin?
        if Settings.multi_application == 'false'
          @application_name =  Settings.single_application_mode_name
        else
          @application_name = Application.find(application_id).name
        end

        dates = (1.month.ago.to_date..Date.today).map{ |date| date.strftime("%b %d") }

        user_subsctiptions=User.all.group_by {|d| d.created_at.to_date}
        users = (1.month.ago.to_date..Date.today).map{ |date| user_subsctiptions[date].nil? ? 0 : user_subsctiptions[date].count }

        user_topups=Activity.where(kind: 'topup').group_by {|d| d.created_at.to_date}
        topups = (1.month.ago.to_date..Date.today).map{ |date| user_topups[date].nil? ? 0 : user_topups[date].sum(&:amount).to_f/100 }

        @chart = LazyHighCharts::HighChart.new('graph') do |f|
          f.title(:text => 'User Registration vs Topup in last month')
          f.xAxis(:categories => dates)
          f.series(:name => 'New users', :yAxis => 0, :data => users)
          f.series(:name => 'Top-ups in UKP', :yAxis => 1, :data => topups)

          f.yAxis [
                      {:title => {:text => 'New users', :margin => 70} },
                      {:title => {:text => 'Top-ups in UKP'}, :opposite => true},
                  ]

          f.legend(:align => 'right', :verticalAlign => 'top', :y => 75, :x => -50, :layout => 'vertical',)
          f.chart({:defaultSeriesType=>'column'})
        end

        @voucher = Voucher.new

        @vouchers = Voucher.or({:expire.gt => Date.today}, {expire: nil })

        @top_up_to_bill = Activity.where(kind: 'topup').reject {|r| !r.invoice.nil?}
      else
        @name = @user.user_detail.name || @user.email
        @activities = @user.activities.desc(:created_at).page(params[:page])
        @voucher = Voucher.new
        @amount = params[:amount]
      end

    end
  end

  # check if the user is authenticated, by token
  def create
    if signed_in?
      render json: @current_user.to_json, status: 200
    else
      render text: 'User not authenticated', status: 404
    end
  end
end
