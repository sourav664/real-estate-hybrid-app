import streamlit as st
import pandas as pd
import plotly.express as px
import joblib
import matplotlib.pyplot as plt
import seaborn as sns



class AnalysisApp:
    
    def __init__(self):
       st.set_page_config(page_title="Analysis App")

       st.title('Analytics')
       self.load_data()
       self.map_plot()
       
       self.plot_scatter()
       self.plot_histogram()
       self.plot_pie()
       self.plot_boxplot()
       self.plot_hist_kde()
      
    
    @classmethod
    def load_data(cls):
        
       cls.new_df = pd.read_csv('data/raw/real_estate.csv')
    
    
    def map_plot(self):
        st.header('Sector Price per Sqft Geomap')
        
        regions = self.new_df['region'].unique().tolist()
        regions.insert(0, 'overall')

        select_region = st.selectbox('Select Region', regions , key="region_selector_map")

        if select_region == 'overall':
            group_df = self.new_df.groupby('locality')[['price', 'price_per_sqft', 'superbuiltupareasqft', 'latitude', 'longitude']].mean()
        else:
            filtered_df = self.new_df[self.new_df['region'] == select_region]
            group_df = filtered_df.groupby('locality')[['price', 'price_per_sqft', 'superbuiltupareasqft', 'latitude', 'longitude']].mean()
        
        fig = px.scatter_map(group_df, lat="latitude", lon="longitude", color="price_per_sqft", size='superbuiltupareasqft',
                                color_continuous_scale=px.colors.cyclical.IceFire, zoom=10,
                                map_style="open-street-map", width=1200, height=700, hover_name=group_df.index)

        st.plotly_chart(fig, use_container_width=True)

        
   
        
    def plot_scatter(self):

        st.header('Area Vs Price')

        property_type = st.selectbox('Select Property Type', ['multistorey apartment','builder floor apartment','residential house','villa', 'penthouse'], key="property_type_selector")

       
        fig1 = px.scatter(self.new_df[self.new_df['propertytype'] == property_type], x="superbuiltupareasqft", y="price", color="bedrooms",
                        title="Area Vs Price")

        st.plotly_chart(fig1, use_container_width=True)

    def plot_pie(self):

        st.header('BHK Pie Chart')
        regions = self.new_df['region'].unique().tolist()
        regions.insert(0,'overall')
        
        select_region = st.selectbox('Select Region', regions, key="region_selector_pie")
        if select_region == 'overall':
            fig2 = px.pie(self.new_df, names='bedrooms')

            st.plotly_chart(fig2, use_container_width=True)
        else:
            

            self.new_df = self.new_df[self.new_df['region'] == select_region]
            locality_options = self.new_df['locality'].unique().tolist()
            locality_options.insert(0,'overall')

            selected_sector = st.selectbox('Select Locality', locality_options, key="locality_selector")

            if selected_sector == 'overall':

                fig2 = px.pie(self.new_df, names='bedrooms')

                st.plotly_chart(fig2, use_container_width=True)
            else:

                fig2 = px.pie(self.new_df[self.new_df['locality'] == selected_sector], names='bedrooms')

                st.plotly_chart(fig2, use_container_width=True)
                
    def plot_boxplot(self):
        regions = self.new_df['region'].unique().tolist()
        regions.insert(0,'overall')
        
        st.header('Side by Side BHK price comparison')
        select_region = st.selectbox('Select Region', regions,  key="region_selector_box")
    
        
        if select_region == 'overall':
        
            fig3 = px.box(self.new_df[self.new_df['bedrooms'] <= 4], x='bedrooms', y='price', title='BHK Price Range')

            st.plotly_chart(fig3, use_container_width=True)
            
        else:
            self.new_df = self.new_df[self.new_df['region'] == select_region]
            fig3 = px.box(self.new_df[self.new_df['bedrooms'] <= 4], x='bedrooms', y='price', title='BHK Price Range')

            st.plotly_chart(fig3, use_container_width=True)

    def plot_hist_kde(self):
        regions = self.new_df['region'].unique().tolist()
        regions.insert(0,'overall')

        st.header('Side by Side hist kde plot for property type')
        select_region = st.selectbox('Select Region', regions , key="region_selector_kde")
        
        if select_region == 'overall':
            df_plot = self.new_df 

            
        else:
            df_plot = self.new_df[self.new_df['region'] == select_region]
        
        fig3 = plt.figure(figsize=(12, 8))  
        sns.histplot(df_plot[df_plot['propertytype'] == 'multistorey apartment']['price'],label='multistorey apartment', kde=True)
        sns.histplot(df_plot[df_plot['propertytype'] == 'residential house']['price'], label='residential house', kde=True)
        sns.histplot(df_plot[df_plot['propertytype'] == 'builder floor apartment']['price'], label='builder floor apartment', kde=True)
        sns.histplot(df_plot[df_plot['propertytype'] == 'villa']['price'], label='villa', kde=True)
        sns.histplot(df_plot[df_plot['propertytype'] == 'penthouse']['price'], label='penthouse', kde=True)
        plt.legend()
        st.pyplot(fig3)

    def plot_histogram(self):
      
        st.header("Property Type Vs Price Per Sqft Histogram")

        regions = self.new_df['region'].unique().tolist()
        regions.insert(0, 'overall')

        select_region = st.selectbox('Select Region', regions, key="region_selector_hist")

        if select_region == 'overall':
            df_plot = self.new_df
        else:
            df_plot = self.new_df[self.new_df['region'] == select_region]

        # Check if df_plot is empty
        if df_plot.empty:
            st.warning("No data available for the selected region.")
            return

        fig = px.histogram(
            df_plot,
            x="propertytype",
            y="price_per_sqft",
            color="propertytype",
            histfunc='avg',
            title="Property Type Vs Avg Price Per Sqft Histogram"
        )

        st.plotly_chart(fig, use_container_width=True)
            
        
        
        
        
        
        
        
        
if __name__ == '__main__':
    AnalysisApp()