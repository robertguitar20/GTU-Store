class Api::V1::ItemController < ApplicationController

   before_action :pagination_params , only: [:index] 
  #  before_action :items_serialize , only: [:today_items]

   swagger_controller :item, "Items"

    # GET __ get all items
    def index 
      @items = Item.order(created_at: :desc)
                   .limit(@to)
                   .offset(@from)

      @items_count = Item.all.count
      unless @category_id.nil? 
        @items = @items.where(category_id:@category_id) 
        @items_count = Item.where(category_id:@category_id).count
      end

      begin
        @items =  items_serialize
        render json: { data: @items , items_count: @items_count } 
      rescue => exception 
        render json: { error: exception } , status: :forbidden
      end
    end

    swagger_api :index do
      summary "Get All Items"
      notes "Get All items , by defauls from 0 to 10"
      param :query, :from, :integer, :optional, "Take from"
      param :query, :to, :integer, :optional, "Count"
      param :query, :category_id, :integer, :optional, "Categoty id"

      response :unauthorized
    end




    # GET __ get by id 
    def show 
      begin
        @item = Item.find(params[:id])
        puts @item.images
        render json:{ data: 
            @item.as_json.merge(
                    :images => @item.images,
                    :has_liked => @item.user.ids.first.equal?(@current_user.id)
            )}  , status: :ok
      rescue => exception
        render json: { error: exception } , status: :not_found
      end
    end

    swagger_api :show do
      summary "Get Item by ID"
      notes "Return item by id"
      param :path, :id, :integer, :optional, "Item Id"
      response :unauthorized
      response :not_found
    end

    # GET _ All User Items 
    def user_items 
      unless @current_user.nil?
         @item = Item.where( user_id: @current_user.id ).order('created_at DESC')

         render json: { data:@item } ,  include: 'images' , status: :ok
      end
    end
 
    swagger_api :user_items do
      summary "Get All User Items"
      notes "Return list of user items"
      response :unauthorized
      response :not_found
    end


    def top_items
      begin
        @items = Item.order('reactions DESC').limit(5)
        render json: { data: @items } , status: :ok
      rescue => exception
        render json: { error: exception } , status: :forbidden
      end
    end

    swagger_api :top_items do
      summary "Get Top items"
      notes "Get items , which has more reactions"
      response :unauthorized
      response :forbidden
    end
    
    def today_items
      begin
        @items = Item.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
        @items = items_serialize
        render json: { data: @items } , status: :ok
      rescue => exception 
        render json: { error: exception } , status: :forbidden
      end   
    end

    swagger_api :today_items do
      summary "Get Today posted item"
      notes "Return items , which posted current date"
      response :unauthorized
      response :forbidden
    end
    

    def find_item
      begin
        query = params[:query]
        @items = Item.where("title LIKE ?  OR description LIKE ?" , "%#{query}%" , "%#{query}%")
        @items =  items_serialize
        render json: { data: @items } , status: :ok
      rescue => exception
        render json: { error: exception } , status: :forbidden
      end
    end

    swagger_api :find_item do
      summary "Find item by title"
      notes "Find item by title and description"
      param :form, "query", :string, :required, "Finding query"
      response  :forbidden
      response :unauthorized
      response :not_found
    end

    # POST _ create new item 
    def create
        @item = Item.new(item_params)
        @item.user_id = @current_user.id

        if @item.save
          images = params[:images]
  
          # If has images 
            if !images.nil? and params[:images].is_a?(Array) 
            #iterate through each of the files
            params[:images].each do |file|
                puts file
                @item.images.create!(:image => file, :item_id => @item.id )
            end
          end
          render json: { data: @item }, status: :created
        else
          render json: @item.errors, status: :unprocessable_entity
        end
    end

    swagger_api :create do
      summary "Create new item"
      notes "Create a new item , using FORMDATA"
      param :form, "title", :string, :optional, "Title"
      param :form, "description", :string, :optional, "Description"
      param :form, "price", :integer, :optional, "Price"
      param :form, "category_id", :integer, :optional, "Category id"
      param :form, "images[]", :array, :optional, "Images"

      response :unauthorized
      response :not_acceptable
      response :unprocessable_entity
    end
    
     
    def update
      @item = Item.find_by_id(params[:id])

      if @current_user.id == @item.user_id
          if @item.update(item_params)
            # If has images 
          if params[:images].nil? and params[:images].is_a?(Array) 
              #iterate through each of the files
              params[:images].each do |file|
                  puts file.methods
                  @item.images.create!(:image => file, :item_id => params[:id] )
              end
              render json: { status: :updated } , status: :unprocessable_entity
          end
        end
        else

          render json: { data:[]  , status: :not_have_permission } , status: :forbidden
      end
    end

    swagger_api :update do
      summary "Update item"
      notes "Update current item , using also FORMDATA"
      param :path , :id , :integer , :required , 'Item ID'
      param :form, "title", :string, :optional, "Title"
      param :form, "description", :string, :optional, "Description"
      param :form, "price", :integer, :optional, "Price"
      param :form, "category_id", :integer, :optional, "Category id"
      param :form, "images[]", :array, :optional, "Images"

      response :unauthorized
      response :not_acceptable
      response :unprocessable_entity
    end


    # DELETE _ remove item with images
    def destroy 

      begin
        @item = Item.find_by_id(params[:id])

        if @current_user.id == @item.user_id
            @item.destroy
            render json: { data: @user , status: :deleted } , status: :ok
        else
          render json: { data:[]  , status: :not_have_permission } , status: :forbidden
        end
      rescue => exception  
        render json: { error: exception  } , status: :forbidden
      end
    end

    swagger_api :destroy do
      summary "Delete item"
      notes "Delete item by id"
      param :path , :id , :integer , :required , 'Item ID'
      response :unauthorized
      response :not_have_permission
      response :forbidden
    end


    private 
    def items_serialize
      unless @items.nil?
        return  @items.map { |item| 
                item.as_json.merge(
                  :image => unless item.images[0].nil? 
                    item.images[0].image_url
                  end ,
                  :has_liked => item.user.ids.first.equal?(@current_user.id)
                
                )
              }
      end
      return @items
    end

    private
    def item_params
      params.permit(:title , :description , :price , :category_id )
    end


    private 
    def pagination_params
        @from ||= params[:from] || 0
        @to ||= params[:to] || 10
        @category_id ||= params[:category_id] || nil
    end
end

